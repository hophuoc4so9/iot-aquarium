#pragma once

#include <Arduino.h>
#include <PubSubClient.h>

#include "fl_runtime.h"

struct TelemetrySample {
  float temperature;
  bool floatHigh;
  bool floatLow;
  bool motorRunning;
  int directionCode;  // 0=STOPPED, 1=FORWARD, 2=BACKWARD
  int duty;
  bool autoMode;
  unsigned long uptimeMs;
};

class TelemetryRuntime {
public:
  TelemetryRuntime();

  TelemetrySample makeSample(float temperature,
                             bool floatHigh,
                             bool floatLow,
                             bool motorRunning,
                             int directionCode,
                             int duty,
                             bool autoMode,
                             unsigned long uptimeMs) const;

  void publishStatusAndTelemetry(const TelemetrySample& sample,
                                 bool wifiConnected,
                                 bool mqttConnected,
                                 PubSubClient& mqttClient,
                                 long deviceId,
                                 long pondId,
                                 const String& statusTopic,
                                 const String& telemetryTopic,
                                 FlRuntime& flRuntime,
                                 float anomalyThreshold);

private:
  static const int TELEMETRY_BUFFER_SIZE = 20;
  TelemetrySample buffer_[TELEMETRY_BUFFER_SIZE];
  int head_;
  int tail_;
  int count_;

  void enqueue(const TelemetrySample& sample);
  bool dequeue(TelemetrySample& out);

  static const char* directionToString(int directionCode);
  static int computeWaterLevelPercent(bool highTriggered, bool lowTriggered);

  void publishTelemetry(const TelemetrySample& sample,
                        PubSubClient& mqttClient,
                        long deviceId,
                        long pondId,
                        const String& telemetryTopic,
                        FlRuntime& flRuntime,
                        float anomalyThreshold);

  void flushBuffered(PubSubClient& mqttClient,
                    long deviceId,
                    long pondId,
                    const String& telemetryTopic,
                    FlRuntime& flRuntime,
                    float anomalyThreshold);
};
