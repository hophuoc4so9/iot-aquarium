#pragma once

#include <Arduino.h>
#include <Preferences.h>

class FlRuntime {
public:
  FlRuntime();

  void loadFromNvs();
  long currentModelVersion() const;

  float estimateAnomalyScore(float temperatureC,
                             int waterLevelPercent,
                             bool motorRunning,
                             int duty) const;

  void appendTrainingSample(float temperatureC,
                            int waterLevelPercent,
                            bool motorRunning,
                            int duty);

  // Returns JSON payload for train-done/metrics report.
  String handleTrainStart(const String& msg,
                          long deviceId,
                          long pondId,
                          unsigned long uptimeMs);

  // Returns true when the new global model is applied.
  bool handleModelDownload(const String& msg, String& reason);

private:
  static const int MODEL_DIM = 8;
  static const int TRAIN_BUFFER_SIZE = 48;

  struct TrainSample {
    float x[MODEL_DIM];
    float y;
  };

  Preferences prefs_;
  TrainSample trainBuffer_[TRAIN_BUFFER_SIZE];
  int trainHead_;
  int trainCount_;

  float weights_[MODEL_DIM];
  float anomalyThreshold_;
  long currentRoundId_;
  long modelVersion_;
  bool trainingInProgress_;
  bool hasPrevTemp_;
  float prevTempNorm_;

  mutable unsigned long inferCount_;
  mutable unsigned long inferAccumUs_;
  mutable unsigned long inferMaxUs_;
  mutable unsigned long inferLastUs_;

  unsigned long trainCountRuns_;
  unsigned long trainAccumMs_;
  unsigned long trainMaxMs_;
  unsigned long trainLastMs_;

  static uint32_t crc32Bytes(const uint8_t* data, size_t len);
  static uint32_t crc32String(const String& s);

  static bool parseWeightsCsv(const String& csv, float* outWeights, int maxCount, int* parsedCount);
  static String weightsJsonArrayFrom(const float weights[MODEL_DIM]);

  static float normalizeTemp(float tempC);
  static float predictTempNormWithWeights(const float weights[MODEL_DIM], const float x[MODEL_DIM]);

  static void buildFeatures(int waterLevelPercent,
                            bool motorRunning,
                            int duty,
                            float prevTempNorm,
                            float outX[MODEL_DIM]);

  float estimateRecentLossWithWeights(const float weights[MODEL_DIM], int maxSamples) const;

  void saveToNvs();

  String buildTrainDonePayload(bool success,
                               float loss,
                               long sampleCount,
                               const char* reason,
                               long deviceId,
                               long pondId,
                               unsigned long uptimeMs) const;
};
