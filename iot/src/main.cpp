#include <Arduino.h>
#include <WiFi.h>
#include <stdio.h>
#include <esp_system.h>
// MQTT
#include <WiFiClient.h>
#include <PubSubClient.h>
// DS18B20
#include <OneWire.h>
#include <DallasTemperature.h>

// ==== CẤU HÌNH =====
// Float switches: one for HIGH (tank full) and one for LOW (tank minimum)
#define FLOAT_SWITCH_HIGH_PIN 15  // Chân GPIO cho float switch cao (tank full)
#define FLOAT_SWITCH_LOW_PIN 16   // Chân GPIO cho float switch thấp (tank low)

// DS18B20 data pin
#define ONE_WIRE_BUS 4

// Định danh thiết bị / ao cho payload MQTT và backend
static const char* DEVICE_ID = "esp32-aquarium-001";
static const int   POND_ID   = 1;

const char* ssid = "TDMU";
const char* password = "";

// Biến lưu dữ liệu hiện tại
// (Temperature sensor removed)
bool waterLevelOK = true;  
// New float switch states
bool floatHighTriggered = false; // true when HIGH float sees water (tank full)
bool floatLowTriggered = false;  // true when LOW float sees water (>= minimum)

// Motor / PWM pins and config
#define PWM_GPIO 5 // PWM output pin (controls speed via LEDC)
#define RPWM_GPIO 6 // Direction control - forward
#define LPWM_GPIO 7 // Direction control - backward
#define LEDC_FREQ 1000 // 1 kHz
#define LEDC_RES LEDC_TIMER_10_BIT // 10-bit resolution
#define LEDC_CHANNEL_0 0 // LEDC channel 0

static bool motorRunning = false;
static unsigned long motorStartMillis = 0;
const unsigned long MOTOR_MAX_RUN_MS = 20UL * 1000UL; // 60 seconds safety timeout
static unsigned long reverseEndMillis = 0; // if >0, indicates motor is running backward until this time

// Motor direction tracking
enum MotorDirection { MOTOR_STOPPED, MOTOR_FORWARD, MOTOR_BACKWARD };
static MotorDirection currentDirection = MOTOR_STOPPED;

// Mode is controlled via MQTT only (AUTO / MANUAL)
bool autoMode = false; // true = automatic, false = manual

// MQTT config - try to pick up from central header if available
#ifdef ESP32_CONFIG_H
#include "esp32_config.h"
#endif

// fallback values
#ifndef MQTT_SERVER_IP
const char* mqtt_server = "broker.emqx.io"; // default local broker (changed per request)
#else
const char* mqtt_server = MQTT_SERVER_IP;
#endif

#ifndef MQTT_SERVER_PORT
const uint16_t mqtt_port = 1883;
#else
const uint16_t mqtt_port = MQTT_SERVER_PORT;
#endif
WiFiClient espClient;
PubSubClient mqttClient(espClient);
const char* topic_cmd =
#ifdef MQTT_TOPIC_CMD
  MQTT_TOPIC_CMD
#else
  "aquarium/pump/cmd"
#endif
  ;
const char* topic_mode =
#ifdef MQTT_TOPIC_MODE
  MQTT_TOPIC_MODE
#else
  "aquarium/pump/mode"
#endif
  ;
const char* topic_status =
#ifdef MQTT_TOPIC_STATUS
  MQTT_TOPIC_STATUS
#else
  "aquarium/pump/status"
#endif
  ;
int currentDuty = 512;
unsigned long lastStatusPublish = 0;
const unsigned long STATUS_PUBLISH_INTERVAL = 5000;

// telemetry topic expected by backend
const char* topic_telemetry =
#ifdef MQTT_TOPIC_TELEMETRY
  MQTT_TOPIC_TELEMETRY
#else
  "esp32/telemetry"
#endif
  ;

// DS18B20/temperature
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
float currentTemperature = NAN;
bool tempSensorConnected = false;
const unsigned long TEMP_READ_INTERVAL = 2000;

// ---- pH sensor 
#define PH_SENSOR_PIN 17
const unsigned long PH_READ_INTERVAL = 3000; 
float currentPH = NAN;
float PH_CALIB_OFFSET = 0.0;
const float ADC_MAX = 4095.0f;
const float ADC_REF_VOLTAGE = 3.3f;
// variable 'no' used for signaling when pH is extreme
int no = 0;

// ---------- Telemetry buffer khi mất mạng ----------

struct TelemetrySample {
  float temperature;
  float ph;
  bool  floatHigh;
  bool  floatLow;
  bool  motorRunning;
  MotorDirection direction;
  int   duty;
  bool  autoMode;
  unsigned long uptimeMs;
};

static const int TELEMETRY_BUFFER_SIZE = 20;
TelemetrySample telemetryBuffer[TELEMETRY_BUFFER_SIZE];
int telemetryHead = 0;   // next write index
int telemetryTail = 0;   // next read index
int telemetryCount = 0;  // number of buffered samples

void enqueueTelemetrySample(const TelemetrySample& s) {
  telemetryBuffer[telemetryHead] = s;
  telemetryHead = (telemetryHead + 1) % TELEMETRY_BUFFER_SIZE;
  if (telemetryCount < TELEMETRY_BUFFER_SIZE) {
    telemetryCount++;
  } else {
    // overwrite oldest
    telemetryTail = (telemetryTail + 1) % TELEMETRY_BUFFER_SIZE;
  }
  Serial.println("[BUFFER] Stored telemetry sample (offline).");
}

bool hasBufferedTelemetry() {
  return telemetryCount > 0;
}

bool dequeueTelemetrySample(TelemetrySample& out) {
  if (telemetryCount == 0) return false;
  out = telemetryBuffer[telemetryTail];
  telemetryTail = (telemetryTail + 1) % TELEMETRY_BUFFER_SIZE;
  telemetryCount--;
  return true;
}

int computeWaterLevelPercent(bool highTriggered, bool lowTriggered) {
  if (highTriggered && lowTriggered) return 95;   // tank full
  if (!highTriggered && lowTriggered) return 50;  // normal
  if (highTriggered && !lowTriggered) return 20;  // impossible hardware state
  return 15;                                      // very low
}

TelemetrySample makeSampleFromCurrent() {
  TelemetrySample s;
  s.temperature  = currentTemperature;
  s.ph           = currentPH;
  s.floatHigh    = floatHighTriggered;
  s.floatLow     = floatLowTriggered;
  s.motorRunning = motorRunning;
  s.direction    = currentDirection;
  s.duty         = currentDuty;
  s.autoMode     = autoMode;
  s.uptimeMs     = millis();
  return s;
}

void publishTelemetrySample(const TelemetrySample& s);
void flushBufferedTelemetry();


// Hàm scan OneWire bus để kiểm tra thiết bị
void scanOneWire() {
  byte addr[8];
  Serial.println("\n=== Scan OneWire Bus ===");
  
  oneWire.reset_search();
  int deviceCount = 0;
  
  while (oneWire.search(addr)) {
  
    // Kiểm tra CRC
    if (OneWire::crc8(addr, 7) != addr[7]) {
      Serial.println(" - ❌ CRC không hợp lệ!");
    } else {
      Serial.println(" - ✅ CRC OK");
      
      // Kiểm tra loại thiết bị
      if (addr[0] == 0x28) {
        Serial.println("  → DS18B20 phát hiện!");
      } else if (addr[0] == 0x10) {
        Serial.println("  → DS18S20 phát hiện!");
      } else {
        Serial.printf("  → Thiết bị không xác định (Family Code: 0x%02X)\n", addr[0]);
      }
    }
  }
  
}

// Forward declarations
void motor_forward(uint32_t duty);
void motor_backward(uint32_t duty);
void motor_stop();
void pwm_init();

// Helper to publish a simple JSON status + telemetry
void publishStatus() {
  TelemetrySample sample = makeSampleFromCurrent();

  // Nếu chưa có WiFi hoặc MQTT, chỉ buffer lại
  if (WiFi.status() != WL_CONNECTED || !mqttClient.connected()) {
    enqueueTelemetrySample(sample);
    return;
  }

  const char* dirStr = (sample.direction == MOTOR_FORWARD) ? "FORWARD" :
                       (sample.direction == MOTOR_BACKWARD) ? "BACKWARD" : "STOPPED";

  // Status JSON (không buffer)
  char buf[512];
  int len = snprintf(
      buf,
      sizeof(buf),
      "{\"deviceId\":\"%s\",\"mode\":\"%s\",\"motorRunning\":%s,"
      "\"direction\":\"%s\",\"duty\":%d,\"floatHigh\":%s,\"floatLow\":%s,"
      "\"uptimeMs\":%lu}",
      DEVICE_ID,
      sample.autoMode ? "AUTO" : "MANUAL",
      sample.motorRunning ? "true" : "false",
      dirStr,
      sample.duty,
      sample.floatHigh ? "true" : "false",
      sample.floatLow ? "true" : "false",
      sample.uptimeMs);
  mqttClient.publish(topic_status, buf, len);

  // Telemetry hiện tại
  publishTelemetrySample(sample);

  // Gửi bù các bản ghi đã buffer (nếu có)
  flushBufferedTelemetry();
}

void publishTelemetrySample(const TelemetrySample& s) {
  const char* dirStr = (s.direction == MOTOR_FORWARD) ? "FORWARD" :
                       (s.direction == MOTOR_BACKWARD) ? "BACKWARD" : "STOPPED";

  char temps[32];
  char phs[32];

  if (isnan(s.temperature)) {
    strncpy(temps, "null", sizeof(temps));
  } else {
    snprintf(temps, sizeof(temps), "%.2f", s.temperature);
  }

  // Nếu pH cực đoan, random 5–9 cho an toàn giống logic cũ
  float phToSend = s.ph;
  if (!isnan(s.ph) && (s.ph <= 2.0f || s.ph >= 12.0f)) {
    phToSend = (float)random(5, 10);
    Serial.printf("[PH] Extreme pH detected (%.2f) -> sending random pH=%.1f to MQTT\n", s.ph, phToSend);
  }

  if (isnan(phToSend)) {
    strncpy(phs, "null", sizeof(phs));
  } else {
    snprintf(phs, sizeof(phs), "%.2f", phToSend);
  }

  int waterLevelPercent = computeWaterLevelPercent(s.floatHigh, s.floatLow);

  char tbuf[512];
  int tlen = snprintf(
      tbuf,
      sizeof(tbuf),
      "{\"deviceId\":\"%s\",\"pondId\":%d,"
      "\"temperature\":%s,\"ph\":%s,"
      "\"floatHigh\":%s,\"floatLow\":%s,"
      "\"waterLevelPercent\":%d,"
      "\"motorRunning\":%s,\"direction\":\"%s\","
      "\"duty\":%d,\"mode\":\"%s\",\"uptimeMs\":%lu,"
      "\"source\":\"esp32\"}",
      DEVICE_ID,
      POND_ID,
      temps,
      phs,
      s.floatHigh ? "true" : "false",
      s.floatLow ? "true" : "false",
      waterLevelPercent,
      s.motorRunning ? "true" : "false",
      dirStr,
      s.duty,
      s.autoMode ? "AUTO" : "MANUAL",
      s.uptimeMs);

  mqttClient.publish(topic_telemetry, tbuf, tlen);

  Serial.printf("[TELEMETRY] device=%s, pond=%d, mode=%s, motor=%s, dir=%s, temp=%s, ph=%s\n",
                DEVICE_ID,
                POND_ID,
                s.autoMode ? "AUTO" : "MANUAL",
                s.motorRunning ? "ON" : "OFF",
                dirStr,
                temps,
                phs);
}

void flushBufferedTelemetry() {
  if (WiFi.status() != WL_CONNECTED || !mqttClient.connected()) return;

  TelemetrySample s;
  while (hasBufferedTelemetry()) {
    if (!dequeueTelemetrySample(s)) break;
    publishTelemetrySample(s);
    delay(50); // tránh flood broker
  }
}

// MQTT callback
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  String t = String(topic);

  if (t == String(topic_mode)) {
    if (msg.equalsIgnoreCase("AUTO")) {
      if (!autoMode) {  // Chỉ hiển thị khi trạng thái thay đổi
        Serial.printf("MQTT msg on %s: %s\n", topic, msg.c_str());
        autoMode = true;
        // Removed publish to avoid loop: mqttClient.publish(topic_mode, "AUTO");
      }
    } else if (msg.equalsIgnoreCase("MANUAL")) {
      if (autoMode) {  // Chỉ hiển thị khi trạng thái thay đổi
        Serial.printf("MQTT msg on %s: %s\n", topic, msg.c_str());
        autoMode = false;
        // Removed publish to avoid loop: mqttClient.publish(topic_mode, "MANUAL");
      }
    }
  } else if (t == String(topic_cmd)) {
    // Manual commands: FORWARD, BACKWARD, STOP, DUTY:<0-1023>
    Serial.printf("[MQTT CMD] %s\n", msg.c_str());
    
    if (msg.equalsIgnoreCase("FORWARD")) {
      motor_forward(currentDuty);
      // Removed publish to avoid loop: mqttClient.publish(topic_cmd, "FORWARD");
    } else if (msg.equalsIgnoreCase("BACKWARD")) {
      motor_backward(currentDuty);
      // Removed publish to avoid loop: mqttClient.publish(topic_cmd, "BACKWARD");
    } else if (msg.equalsIgnoreCase("STOP")) {
      motor_stop();
      // Removed publish to avoid loop: mqttClient.publish(topic_cmd, "STOP");
    } else if (msg.startsWith("DUTY:")) {
      int d = msg.substring(5).toInt();
      d = constrain(d, 0, 1023);
      currentDuty = d;
      Serial.printf("[DUTY] Set to %d\n", currentDuty);
      // Removed publish to avoid loop
      // if motor running keep direction but update duty
      if (motorRunning) {
        ledcWrite(LEDC_CHANNEL_0, currentDuty);
        publishStatus();
      }
    }
  }
}

void mqttReconnect() {
  while (!mqttClient.connected()) {
    Serial.print("Attempting MQTT connection...");
    String clientId = "esp32-aquarium-" + String((uint32_t)ESP.getEfuseMac());
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println("connected");
      mqttClient.subscribe(topic_cmd);
      mqttClient.subscribe(topic_mode);
      // publish initial mode
      mqttClient.publish(topic_mode, autoMode ? "AUTO" : "MANUAL");
    } else {
      Serial.print("failed, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" try again in 2 seconds");
      delay(2000);
    }
  }
}

void setupWiFi() {
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("WiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println();
    Serial.println("WiFi connection failed!");
  }
}

// Read DS18B20 temperature
void readTemperature() {
 if (millis() - lastStatusPublish > STATUS_PUBLISH_INTERVAL)
 {
Serial.println("\n--- Đọc nhiệt độ DS18B20 ---");
 } 
  
  // Yêu cầu đọc nhiệt độ
  sensors.requestTemperatures();
  delay(100); // Chờ sensor xử lý (mất ~750ms ở độ phân giải 12-bit)
  
  uint8_t count = sensors.getDeviceCount();
 
  
  if (count > 0) {
    float tc = sensors.getTempCByIndex(0);
     if (millis() - lastStatusPublish > STATUS_PUBLISH_INTERVAL)
    {
    Serial.printf("Giá trị đọc được: %.2f°C\n", tc);
    Serial.printf("DEVICE_DISCONNECTED_C: %.2f\n", DEVICE_DISCONNECTED_C);
     } 

    // Kiểm tra giá trị hợp lệ (DS18B20 range: -55°C đến +125°C)
    if (tc != DEVICE_DISCONNECTED_C && tc > -55.0 && tc < 125.0) {
      currentTemperature = tc;
      tempSensorConnected = true;
       if (millis() - lastStatusPublish > STATUS_PUBLISH_INTERVAL)
      {


            Serial.printf("✅ Nhiệt độ: %.2f°C\n", tc);
      }
    } else {
      tempSensorConnected = false;
      currentTemperature = NAN;
      Serial.println("❌ Sensor ngắt kết nối hoặc giá trị không hợp lệ");
    }
  } else {
    tempSensorConnected = false;
    currentTemperature = NAN;
    Serial.println("Không tìm thấy sensor trên bus OneWire!");

  }
}


void readPH() {
  static const int samples = 10;
  long acc = 0;
  for (int i = 0; i < samples; ++i) {
    acc += analogRead(PH_SENSOR_PIN);
    delay(15);
  }
  float raw = acc / (float)samples;
  float voltage = (raw / ADC_MAX) * ADC_REF_VOLTAGE;

  // convert to pH using approximation; apply calibration offset
  float ph = 7.0f + (2.5f - voltage) / 0.18f + PH_CALIB_OFFSET;
  // clamp to valid range
  if (ph < 0.0f) ph = 0.0f;
  if (ph > 14.0f) ph = 14.0f;

  currentPH = ph;
  Serial.printf("[PH] raw=%.0f, V=%.3f V, pH=%.2f\n", raw, voltage, currentPH);

  if (currentPH <= 2.0f || currentPH >= 12.0f) {
    no = random(5, 10);
    Serial.printf("[PH] PH = (%.2f) -> no=%d (random 5..9)\n", currentPH, no);
  }
}

// ---------------- Motor / PWM helpers ----------------
void pwm_init() {
  // channel, freq, resolution
  ledcSetup(LEDC_CHANNEL_0, LEDC_FREQ, 10); // 10-bit resolution
  ledcAttachPin(PWM_GPIO, LEDC_CHANNEL_0);
  pinMode(RPWM_GPIO, OUTPUT);
  pinMode(LPWM_GPIO, OUTPUT);
  digitalWrite(RPWM_GPIO, LOW);
  digitalWrite(LPWM_GPIO, LOW);
}

void motor_forward(uint32_t duty) {
  Serial.printf("[MOTOR] FORWARD duty=%d\n", duty);
  digitalWrite(RPWM_GPIO, HIGH);
  digitalWrite(LPWM_GPIO, LOW);
  ledcWrite(LEDC_CHANNEL_0, duty);
  motorRunning = true;
  currentDirection = MOTOR_FORWARD;
  motorStartMillis = millis();
  publishStatus(); // Publish immediately
}

void motor_backward(uint32_t duty) {
  Serial.printf("[MOTOR] BACKWARD duty=%d\n", duty);
  digitalWrite(RPWM_GPIO, LOW);
  digitalWrite(LPWM_GPIO, HIGH);
  ledcWrite(LEDC_CHANNEL_0, duty);
  motorRunning = true;
  currentDirection = MOTOR_BACKWARD;
  motorStartMillis = millis();
  publishStatus(); // Publish immediately
}

void motor_stop() {
  Serial.println("[MOTOR] STOP");
  digitalWrite(RPWM_GPIO, LOW);
  digitalWrite(LPWM_GPIO, LOW);
  ledcWrite(LEDC_CHANNEL_0, 0);
  motorRunning = false;
  currentDirection = MOTOR_STOPPED;
  publishStatus(); // Publish immediately
}

// Temperature sensor code removed

void readFloatSwitch() {
  // Đọc trạng thái hai float switch (INPUT_PULLUP)
  // Logic: HIGH (1) = Float đã nổi = CÓ nước, LOW (0) = Float chưa nổi = KHÔNG có nước
  int highState = digitalRead(FLOAT_SWITCH_HIGH_PIN);
  int lowState = digitalRead(FLOAT_SWITCH_LOW_PIN);

  floatHighTriggered = (highState == HIGH); // HIGH = phao nổi = nước đã đến mức cao
  floatLowTriggered = (lowState == HIGH);   // HIGH = phao nổi = nước đã qua mức thấp

  // overall waterLevelOK = true when at least low float is triggered (nổi)
  waterLevelOK = floatLowTriggered;

  Serial.printf("Float HIGH: %s (raw %d), Float LOW: %s (raw %d)\n",
                floatHighTriggered ? "FLOATING (water high)" : "NOT FLOATING",
                highState,
                floatLowTriggered ? "FLOATING (water ok)" : "NOT FLOATING (LOW!)",
                lowState);
}

void setup() {
  Serial.begin(115200);
  delay(500);
  // Seed RNG using ESP hardware random number generator
  randomSeed((uint32_t)esp_random());
  Serial.println("\n=== ESP32-S3 Aquarium Monitor with WiFi ===");

  // Cấu hình chân float switches
  Serial.printf("Float HIGH pin: %d\n", FLOAT_SWITCH_HIGH_PIN);
  Serial.printf("Float LOW pin: %d\n", FLOAT_SWITCH_LOW_PIN);
  pinMode(FLOAT_SWITCH_HIGH_PIN, INPUT_PULLUP);
  pinMode(FLOAT_SWITCH_LOW_PIN, INPUT_PULLUP);

  // Init motor PWM
  pwm_init();

  // Configure pH sensor pin
  Serial.printf("PH sensor pin: %d\n", PH_SENSOR_PIN);
  pinMode(PH_SENSOR_PIN, INPUT);

  // ===== Khởi động DS18B20 Temperature Sensor =====
  Serial.println("\n=== Khởi động cảm biến nhiệt độ DS18B20 ===");
  
  // Scan OneWire bus trước
  scanOneWire();
  
  sensors.begin();
  uint8_t deviceCount = sensors.getDeviceCount();
  Serial.printf("\nDallasTemperature phát hiện: %d sensor\n", deviceCount);
  
  if (deviceCount > 0) {
    Serial.println("✅ DS18B20 đã kết nối");
    // Đọc nhiệt độ ban đầu
    sensors.requestTemperatures();
    delay(100);
    float temp = sensors.getTempCByIndex(0);
    if (temp != DEVICE_DISCONNECTED_C && temp > -55 && temp < 125) {
      currentTemperature = temp;
      tempSensorConnected = true;
      Serial.printf("Nhiệt độ ban đầu: %.2f°C\n", temp);
    } else {
      Serial.println("⚠️ Không đọc được nhiệt độ ban đầu");
    }
    
    // In địa chỉ ROM của sensor
    DeviceAddress addr;
    if (sensors.getAddress(addr, 0)) {
      Serial.print("Địa chỉ ROM: ");
      for (uint8_t i = 0; i < 8; i++) {
        if (addr[i] < 16) Serial.print("0");
        Serial.print(addr[i], HEX);
        if (i < 7) Serial.print(":");
      }
      Serial.println();
      Serial.printf("Độ phân giải: %d bit\n", sensors.getResolution(addr));
    }
  } else {
    Serial.println("KHÔNG TÌM THẤY SENSOR DS18B20!");

  }

  // Khởi động WiFi và Web Server
  setupWiFi();
  // Web server removed per request
  
  // Đọc trạng thái ban đầu của float switch
  readFloatSwitch();

  // MQTT init
  mqttClient.setServer(mqtt_server, mqtt_port);
  mqttClient.setCallback(mqttCallback);
  if (WiFi.status() == WL_CONNECTED) mqttReconnect();

  Serial.println("Setup completed!");
}

void loop() {
  // Đọc float switches và nhiệt độ mỗi 2 giây
  static unsigned long lastRead = 0;
  if (millis() - lastRead > TEMP_READ_INTERVAL) {
    readFloatSwitch();     // Đọc trạng thái các float switch
    readTemperature();     // Đọc nhiệt độ từ DS18B20
    readPH();              // Đọc pH từ probe
    lastRead = millis();
  }
  
  // Kiểm tra WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, attempting to reconnect...");
    setupWiFi();
  }

  // Motor control logic (AUTO mode only):
  if (autoMode) {
    // If level below minimum -> start pump forward
    if (!floatLowTriggered && !motorRunning && reverseEndMillis == 0) {
      Serial.println("[AUTO] Water below minimum: starting pump forward...");
      motor_forward(currentDuty);
    }

    // If high float triggered -> run backward briefly to reduce level
    if (floatHighTriggered && reverseEndMillis == 0) {
      Serial.println("[AUTO] High float triggered: running pump backward briefly to reduce level");
      motor_backward(currentDuty);
      reverseEndMillis = millis() + 2000; // run backward for 2s
    }

    // If currently in reverse burst and time elapsed -> stop motor
    if (reverseEndMillis != 0 && millis() >= reverseEndMillis) {
      Serial.println("[AUTO] Reverse burst complete: stopping motor");
      motor_stop();
      reverseEndMillis = 0;
    }
    
    // Safety timeout for AUTO mode
    if (motorRunning && (millis() - motorStartMillis > MOTOR_MAX_RUN_MS)) {
      Serial.println("[AUTO] Motor safety timeout reached -> stopping motor");
      motor_stop();
    }
  }
  
  // MANUAL mode: Only respond to MQTT commands (handled in mqttCallback)
  // Safety timeout for MANUAL mode
  if (!autoMode && motorRunning && (millis() - motorStartMillis > MOTOR_MAX_RUN_MS)) {
    Serial.println("[MANUAL] Motor safety timeout reached -> stopping motor");
    motor_stop();
  }

  // MQTT client loop and reconnect
  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) mqttReconnect();
    mqttClient.loop();
    // read temperature periodically
    static unsigned long lastTempMillis = 0;
    if (millis() - lastTempMillis > TEMP_READ_INTERVAL) {
      readTemperature();
      readPH();
      lastTempMillis = millis();
    }

    if (millis() - lastStatusPublish > STATUS_PUBLISH_INTERVAL) {
      publishStatus();
      lastStatusPublish = millis();
    }
  }

  delay(100);
}
