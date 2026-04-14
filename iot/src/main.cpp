#include <Arduino.h>
#include <WiFi.h>
#include <stdio.h>
#include <esp_system.h>
// MQTT
#include <WiFiClient.h>
#include <PubSubClient.h>
#include "fl_runtime.h"
#include "telemetry_runtime.h"
#include "mqtt_runtime.h"
#include "motor_runtime.h"
// DS18B20
#include <OneWire.h>
#include <DallasTemperature.h>

// ==== CẤU HÌNH =====
// Float switches: one for HIGH (tank full) and one for LOW (tank minimum)
#define FLOAT_SWITCH_HIGH_PIN 16  // Chân GPIO cho float switch cao (tank full)
#define FLOAT_SWITCH_LOW_PIN 15   // Chân GPIO cho float switch thấp (tank low)

// DS18B20 data pin
#define ONE_WIRE_BUS 4

// Định danh thiết bị / ao cho payload MQTT và backend
static const long DEVICE_ID = 5;
static const long POND_ID   = 5;

const char* ssid = "HO TUONG VSIP";
const char* password = "111222333";

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

const unsigned long MOTOR_MAX_RUN_MS = 60UL * 1000UL; // 60 seconds safety timeout
static unsigned long reverseEndMillis = 0; // if >0, indicates motor is running backward until this time

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
  "nckh/iot-aquarium/esp32/telemetry"
#endif
  ;

static String flTrainStartTopic() {
  return String("fl/model/") + String(DEVICE_ID) + "/train/start";
}

static String flModelDownloadTopic() {
  return String("fl/model/") + String(DEVICE_ID) + "/download";
}

static String flTrainDoneTopic() {
  return String("fl/model/") + String(DEVICE_ID) + "/train/done";
}

static String flMetricsTopic() {
  return String("fl/metrics/") + String(DEVICE_ID) + "/report";
}

FlRuntime flRuntime;
TelemetryRuntime telemetryRuntime;
MotorRuntime motorRuntime(PWM_GPIO, RPWM_GPIO, LPWM_GPIO, LEDC_CHANNEL_0, LEDC_FREQ, 10);

static String pondCmdTopic() {
  return String("aquarium/pond/") + String(POND_ID) + "/pump/cmd";
}

static String pondModeTopic() {
  return String("aquarium/pond/") + String(POND_ID) + "/pump/mode";
}

static String pondStatusTopic() {
  return String("nckh/iot-aquarium/esp32/pond/") + String(POND_ID) + "/status";
}

static String pondTelemetryTopic() {
  return String("nckh/iot-aquarium/esp32/pond/") + String(POND_ID) + "/telemetry";
}

// DS18B20/temperature
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
float currentTemperature = NAN;
bool tempSensorConnected = false;
const unsigned long TEMP_READ_INTERVAL = 2000;

void handleFlTrainStart(const String& msg) {
  if (WiFi.status() != WL_CONNECTED || !mqttClient.connected()) return;

  String payload = flRuntime.handleTrainStart(msg, DEVICE_ID, POND_ID, millis());
  if (payload.length() == 0) return;

  String doneTopic = flTrainDoneTopic();
  String metricsTopic = flMetricsTopic();
  mqttClient.publish(doneTopic.c_str(), payload.c_str());
  mqttClient.publish(metricsTopic.c_str(), payload.c_str());
}

void handleFlModelDownload(const String& msg) {
  String reason;
  bool applied = flRuntime.handleModelDownload(msg, reason);
  if (!applied && reason.length() > 0) {
    Serial.printf("[FL] %s\n", reason.c_str());
  }
  Serial.printf("[FL] Model update command received. version=%ld payload=%s\n",
                flRuntime.currentModelVersion(),
                msg.c_str());
}

TelemetrySample makeSampleFromCurrent() {
  int directionCode = 0;
  if (motorRuntime.direction() == MOTOR_FORWARD) directionCode = 1;
  else if (motorRuntime.direction() == MOTOR_BACKWARD) directionCode = 2;

  return telemetryRuntime.makeSample(
      currentTemperature,
      floatHighTriggered,
      floatLowTriggered,
      motorRuntime.running(),
      directionCode,
      currentDuty,
      autoMode,
      millis());
}


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
  telemetryRuntime.publishStatusAndTelemetry(
      sample,
      WiFi.status() == WL_CONNECTED,
      mqttClient.connected(),
      mqttClient,
      DEVICE_ID,
      POND_ID,
      pondStatusTopic(),
      pondTelemetryTopic(),
      flRuntime,
      0.12f);
}

// MQTT callback
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  msg.trim();
  String t = String(topic);
  String perPondCmd = pondCmdTopic();
  String perPondMode = pondModeTopic();
  String trainStartTopic = flTrainStartTopic();
  String modelDownloadTopic = flModelDownloadTopic();

  if (t == String(topic_mode) || t == perPondMode) {
    if (msg.equalsIgnoreCase("AUTO")) {
      if (!autoMode) {  // Chỉ hiển thị khi trạng thái thay đổi
        Serial.printf("MQTT msg on %s: %s\n", topic, msg.c_str());
        autoMode = true;
        publishStatus();
      }
    } else if (msg.equalsIgnoreCase("MANUAL")) {
      if (autoMode) {  // Chỉ hiển thị khi trạng thái thay đổi
        Serial.printf("MQTT msg on %s: %s\n", topic, msg.c_str());
        autoMode = false;
        publishStatus();
      }
    }
  } else if (t == String(topic_cmd) || t == perPondCmd) {
    // Lệnh điều khiển cơ bản: FORWARD, BACKWARD, STOP, DUTY:<0-1023>
    Serial.printf("[MQTT CMD] %s\n", msg.c_str());

    if (msg.equalsIgnoreCase("FORWARD")) {
      motor_forward(currentDuty);
    } else if (msg.equalsIgnoreCase("BACKWARD")) {
      motor_backward(currentDuty);
    } else if (msg.equalsIgnoreCase("STOP")) {
      motor_stop();
    } else if (msg.startsWith("DUTY:")) {
      int d = msg.substring(5).toInt();
      d = constrain(d, 0, 1023);
      currentDuty = d;
      Serial.printf("[DUTY] Set to %d\n", currentDuty);

      // Nếu motor đang chạy thì cập nhật duty ngay.
      if (motorRuntime.running()) {
        motorRuntime.applyDuty(currentDuty);
      }
      publishStatus();
    } else {
      Serial.printf("[MQTT CMD] Invalid command: %s\n", msg.c_str());
    }
  } else if (t == trainStartTopic) {
    handleFlTrainStart(msg);
  } else if (t == modelDownloadTopic) {
    handleFlModelDownload(msg);
  }
}

void mqttReconnect() {
  String clientId = "esp32-aquarium-" + String((uint32_t)ESP.getEfuseMac());
  mqttEnsureConnected(
      mqttClient,
      clientId,
      topic_cmd,
      topic_mode,
      pondCmdTopic(),
      pondModeTopic(),
      flTrainStartTopic(),
      flModelDownloadTopic(),
      autoMode);
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


// ---------------- Motor / PWM helpers ----------------
void pwm_init() {
  motorRuntime.init();
}

void motor_forward(uint32_t duty) {
  Serial.printf("[MOTOR] FORWARD duty=%d\n", duty);
  motorRuntime.forward(duty);
  publishStatus(); // Publish immediately
}

void motor_backward(uint32_t duty) {
  Serial.printf("[MOTOR] BACKWARD duty=%d\n", duty);
  motorRuntime.backward(duty);
  publishStatus(); // Publish immediately
}

void motor_stop() {
  Serial.println("[MOTOR] STOP");
  motorRuntime.stop();
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

  flRuntime.loadFromNvs();

  // Cấu hình chân float switches
  Serial.printf("Float HIGH pin: %d\n", FLOAT_SWITCH_HIGH_PIN);
  Serial.printf("Float LOW pin: %d\n", FLOAT_SWITCH_LOW_PIN);
  pinMode(FLOAT_SWITCH_HIGH_PIN, INPUT_PULLUP);
  pinMode(FLOAT_SWITCH_LOW_PIN, INPUT_PULLUP);

  // Init motor PWM
  pwm_init();

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
    if (!floatLowTriggered && !motorRuntime.running() && reverseEndMillis == 0) {
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
    if (motorRuntime.running() && (millis() - motorRuntime.startMillis() > MOTOR_MAX_RUN_MS)) {
      Serial.println("[AUTO] Motor safety timeout reached -> stopping motor");
      motor_stop();
    }
  }
  
  // MANUAL mode: Only respond to MQTT commands (handled in mqttCallback)
  // Safety timeout for MANUAL mode
  if (!autoMode && motorRuntime.running() && (millis() - motorRuntime.startMillis() > MOTOR_MAX_RUN_MS)) {
    Serial.println("[MANUAL] Motor safety timeout reached -> stopping motor");
    motor_stop();
  }

  // MQTT client loop and reconnect
  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) mqttReconnect();
    mqttClient.loop();

    if (millis() - lastStatusPublish > STATUS_PUBLISH_INTERVAL) {
      publishStatus();
      lastStatusPublish = millis();
    }
  }

  delay(100);
}
