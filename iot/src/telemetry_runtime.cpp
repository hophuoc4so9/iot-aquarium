#include "telemetry_runtime.h"

TelemetryRuntime::TelemetryRuntime() : head_(0), tail_(0), count_(0) {}

TelemetrySample TelemetryRuntime::makeSample(float temperature,
                                             bool floatHigh,
                                             bool floatLow,
                                             bool motorRunning,
                                             int directionCode,
                                             int duty,
                                             bool autoMode,
                                             unsigned long uptimeMs) const {
  TelemetrySample s;
  s.temperature = temperature;
  s.floatHigh = floatHigh;
  s.floatLow = floatLow;
  s.motorRunning = motorRunning;
  s.directionCode = directionCode;
  s.duty = duty;
  s.autoMode = autoMode;
  s.uptimeMs = uptimeMs;
  return s;
}

void TelemetryRuntime::publishStatusAndTelemetry(const TelemetrySample& sample,
                                                 bool wifiConnected,
                                                 bool mqttConnected,
                                                 PubSubClient& mqttClient,
                                                 long deviceId,
                                                 long pondId,
                                                 const String& statusTopic,
                                                 const String& telemetryTopic,
                                                 FlRuntime& flRuntime,
                                                 float anomalyThreshold) {
  if (!wifiConnected || !mqttConnected) {
    enqueue(sample);
    return;
  }

  const char* dirStr = directionToString(sample.directionCode);

  char buf[512];
  int len = snprintf(
      buf,
      sizeof(buf),
      "{\"deviceId\":%ld,\"mode\":\"%s\",\"motorRunning\":%s,"
      "\"direction\":\"%s\",\"duty\":%d,\"floatHigh\":%s,\"floatLow\":%s,"
      "\"uptime_ms\":%lu}",
      deviceId,
      sample.autoMode ? "AUTO" : "MANUAL",
      sample.motorRunning ? "true" : "false",
      dirStr,
      sample.duty,
      sample.floatHigh ? "true" : "false",
      sample.floatLow ? "true" : "false",
      sample.uptimeMs);

  mqttClient.publish(statusTopic.c_str(), buf, len);
  publishTelemetry(sample, mqttClient, deviceId, pondId, telemetryTopic, flRuntime, anomalyThreshold);
  flushBuffered(mqttClient, deviceId, pondId, telemetryTopic, flRuntime, anomalyThreshold);
}

void TelemetryRuntime::enqueue(const TelemetrySample& sample) {
  buffer_[head_] = sample;
  head_ = (head_ + 1) % TELEMETRY_BUFFER_SIZE;
  if (count_ < TELEMETRY_BUFFER_SIZE) {
    count_++;
  } else {
    tail_ = (tail_ + 1) % TELEMETRY_BUFFER_SIZE;
  }
}

bool TelemetryRuntime::dequeue(TelemetrySample& out) {
  if (count_ == 0) return false;
  out = buffer_[tail_];
  tail_ = (tail_ + 1) % TELEMETRY_BUFFER_SIZE;
  count_--;
  return true;
}

const char* TelemetryRuntime::directionToString(int directionCode) {
  if (directionCode == 1) return "FORWARD";
  if (directionCode == 2) return "BACKWARD";
  return "STOPPED";
}

int TelemetryRuntime::computeWaterLevelPercent(bool highTriggered, bool lowTriggered) {
  if (highTriggered && lowTriggered) return 95;
  if (!highTriggered && lowTriggered) return 50;
  if (highTriggered && !lowTriggered) return 20;
  return 15;
}

void TelemetryRuntime::publishTelemetry(const TelemetrySample& sample,
                                        PubSubClient& mqttClient,
                                        long deviceId,
                                        long pondId,
                                        const String& telemetryTopic,
                                        FlRuntime& flRuntime,
                                        float anomalyThreshold) {
  const char* dirStr = directionToString(sample.directionCode);

  char temps[32];
  if (isnan(sample.temperature)) {
    strncpy(temps, "null", sizeof(temps));
  } else {
    snprintf(temps, sizeof(temps), "%.2f", sample.temperature);
  }

  int waterLevelPercent = computeWaterLevelPercent(sample.floatHigh, sample.floatLow);
  float anomalyScore = flRuntime.estimateAnomalyScore(
      sample.temperature,
      waterLevelPercent,
      sample.motorRunning,
      sample.duty);

  flRuntime.appendTrainingSample(
      sample.temperature,
      waterLevelPercent,
      sample.motorRunning,
      sample.duty);

  char tbuf[512];
  int tlen = snprintf(
      tbuf,
      sizeof(tbuf),
      "{\"deviceId\":%ld,\"pondId\":%ld,"
      "\"temperature\":%s,"
      "\"floatHigh\":%s,\"floatLow\":%s,"
      "\"waterLevelPercent\":%d,"
      "\"motorRunning\":%s,\"direction\":\"%s\","
      "\"anomalyScore\":%.5f,\"anomalyFlag\":%s,"
      "\"duty\":%d,\"mode\":\"%s\",\"uptime_ms\":%lu,"
      "\"source\":\"esp32\"}",
      deviceId,
      pondId,
      temps,
      sample.floatHigh ? "true" : "false",
      sample.floatLow ? "true" : "false",
      waterLevelPercent,
      sample.motorRunning ? "true" : "false",
      dirStr,
      anomalyScore,
      anomalyScore > anomalyThreshold ? "true" : "false",
      sample.duty,
      sample.autoMode ? "AUTO" : "MANUAL",
      sample.uptimeMs);

  mqttClient.publish(telemetryTopic.c_str(), tbuf, tlen);
}

void TelemetryRuntime::flushBuffered(PubSubClient& mqttClient,
                                     long deviceId,
                                     long pondId,
                                     const String& telemetryTopic,
                                     FlRuntime& flRuntime,
                                     float anomalyThreshold) {
  TelemetrySample s;
  while (dequeue(s)) {
    publishTelemetry(s, mqttClient, deviceId, pondId, telemetryTopic, flRuntime, anomalyThreshold);
    delay(50);
  }
}
