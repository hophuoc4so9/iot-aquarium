#include "fl_runtime.h"

#include <math.h>
#include <stdlib.h>

FlRuntime::FlRuntime()
    : trainHead_(0),
      trainCount_(0),
      anomalyThreshold_(0.12f),
      currentRoundId_(0),
      modelVersion_(0),
      trainingInProgress_(false),
      hasPrevTemp_(false),
      prevTempNorm_(0.0f),
      inferCount_(0),
      inferAccumUs_(0),
      inferMaxUs_(0),
      inferLastUs_(0),
      trainCountRuns_(0),
      trainAccumMs_(0),
      trainMaxMs_(0),
      trainLastMs_(0) {
  // v2 default: autoregressive linear model with lightweight nonlinear interactions.
  weights_[0] = 0.03f;  // bias
  weights_[1] = 0.08f;  // water level
  weights_[2] = 0.03f;  // motor state
  weights_[3] = 0.02f;  // duty
  weights_[4] = 0.78f;  // previous temperature (dominant)
  weights_[5] = 0.02f;  // water*duty
  weights_[6] = 0.02f;  // motor*duty
  weights_[7] = 0.02f;  // water^2
}

void FlRuntime::loadFromNvs() {
  if (!prefs_.begin("flmodel", true)) return;
  long savedVersion = prefs_.getLong("version", 0);
  String savedWeights = prefs_.getString("weights", "");
  prefs_.end();

  if (savedWeights.length() < 3) {
    // No valid persisted model yet: keep defaults and persist 8D baseline.
    saveToNvs();
    return;
  }

  String csv = savedWeights;
  csv.replace("[", "");
  csv.replace("]", "");

  float parsed[MODEL_DIM];
  int parsedCount = 0;
  if (!parseWeightsCsv(csv, parsed, MODEL_DIM, &parsedCount)) {
    saveToNvs();
    return;
  }

  if (parsedCount != MODEL_DIM) {
    // Persist defaults to overwrite old/non-8D model states.
    saveToNvs();
    return;
  }

  for (int i = 0; i < MODEL_DIM; ++i) {
    weights_[i] = parsed[i];
  }

  modelVersion_ = savedVersion;
  Serial.printf("[FL] Restored model from NVS. version=%ld\n", modelVersion_);
}

long FlRuntime::currentModelVersion() const {
  return modelVersion_;
}

float FlRuntime::estimateAnomalyScore(float temperatureC,
                                      int waterLevelPercent,
                                      bool motorRunning,
                                      int duty) const {
  if (isnan(temperatureC)) return 0.0f;

  unsigned long t0 = micros();

  float x[MODEL_DIM];
  float prev = hasPrevTemp_ ? prevTempNorm_ : normalizeTemp(temperatureC);
  buildFeatures(waterLevelPercent, motorRunning, duty, prev, x);
  float y = normalizeTemp(temperatureC);
  float pred = predictTempNormWithWeights(weights_, x);
  float score = fabsf(pred - y);

  unsigned long dt = micros() - t0;
  inferLastUs_ = dt;
  inferCount_++;
  inferAccumUs_ += dt;
  if (dt > inferMaxUs_) inferMaxUs_ = dt;
  if ((inferCount_ % 30UL) == 0UL) {
    float avgUs = (float)inferAccumUs_ / (float)inferCount_;
    Serial.printf("[FL-BENCH] infer_us last=%lu avg=%.2f max=%lu n=%lu\n",
                  inferLastUs_,
                  avgUs,
                  inferMaxUs_,
                  inferCount_);
  }

  return score;
}

void FlRuntime::appendTrainingSample(float temperatureC,
                                     int waterLevelPercent,
                                     bool motorRunning,
                                     int duty) {
  if (isnan(temperatureC)) return;

  float currNorm = normalizeTemp(temperatureC);
  if (!hasPrevTemp_) {
    hasPrevTemp_ = true;
    prevTempNorm_ = currNorm;
    return;
  }

  TrainSample sample;
  buildFeatures(waterLevelPercent, motorRunning, duty, prevTempNorm_, sample.x);
  sample.y = currNorm;

  trainBuffer_[trainHead_] = sample;
  trainHead_ = (trainHead_ + 1) % TRAIN_BUFFER_SIZE;
  if (trainCount_ < TRAIN_BUFFER_SIZE) {
    trainCount_++;
  }

  prevTempNorm_ = currNorm;
}

String FlRuntime::handleTrainStart(const String& msg,
                                   long deviceId,
                                   long pondId,
                                   unsigned long uptimeMs) {
  unsigned long trainStartMs = millis();

  long roundId = currentRoundId_;
  long epochs = 1;
  long sampleCount = 32;

  int roundPos = msg.indexOf("ROUND:");
  if (roundPos >= 0) {
    int sep = msg.indexOf('|', roundPos);
    String roundText = (sep >= 0) ? msg.substring(roundPos + 6, sep) : msg.substring(roundPos + 6);
    roundId = roundText.toInt();
  }

  int samplePos = msg.indexOf("SAMPLES:");
  if (samplePos >= 0) {
    int sep = msg.indexOf('|', samplePos);
    String sampleText = (sep >= 0) ? msg.substring(samplePos + 8, sep) : msg.substring(samplePos + 8);
    long parsed = sampleText.toInt();
    if (parsed > 0) sampleCount = parsed;
  }

  int epochsPos = msg.indexOf("EPOCHS:");
  if (epochsPos >= 0) {
    int sep = msg.indexOf('|', epochsPos);
    String epochsText = (sep >= 0) ? msg.substring(epochsPos + 7, sep) : msg.substring(epochsPos + 7);
    long parsed = epochsText.toInt();
    if (parsed > 0) epochs = parsed;
  }

  if (trainingInProgress_) {
    return buildTrainDonePayload(false, -1.0f, 0, "busy", deviceId, pondId, uptimeMs);
  }

  trainingInProgress_ = true;
  currentRoundId_ = roundId;
  Serial.printf("[FL] Start local training round=%ld payload=%s\n", currentRoundId_, msg.c_str());

  if (trainCount_ == 0) {
    trainingInProgress_ = false;
    return buildTrainDonePayload(false, -1.0f, 0, "no_data", deviceId, pondId, uptimeMs);
  }

  int trainSamples = (int)sampleCount;
  if (trainSamples > trainCount_) trainSamples = trainCount_;
  if (trainSamples < 1) trainSamples = trainCount_;

  float lr = 0.03f;
  float mse = 0.0f;
  int updates = 0;

  for (int e = 0; e < epochs; ++e) {
    for (int i = 0; i < trainSamples; ++i) {
      int idx = trainHead_ - 1 - i;
      if (idx < 0) idx += TRAIN_BUFFER_SIZE;

      TrainSample& s = trainBuffer_[idx];
      float pred = predictTempNormWithWeights(weights_, s.x);
      float err = pred - s.y;
      mse += err * err;
      updates++;

      // Clip gradient to reduce update spikes on noisy samples.
      float clippedErr = err;
      if (clippedErr > 0.5f) clippedErr = 0.5f;
      if (clippedErr < -0.5f) clippedErr = -0.5f;

      for (int j = 0; j < MODEL_DIM; ++j) {
        weights_[j] -= lr * clippedErr * s.x[j];
      }
    }
  }

  float finalLoss = updates > 0 ? (mse / (float)updates) : -1.0f;
  saveToNvs();

  trainLastMs_ = millis() - trainStartMs;
  trainCountRuns_++;
  trainAccumMs_ += trainLastMs_;
  if (trainLastMs_ > trainMaxMs_) trainMaxMs_ = trainLastMs_;
  float trainAvgMs = (float)trainAccumMs_ / (float)trainCountRuns_;
  Serial.printf("[FL-BENCH] train_ms last=%lu avg=%.2f max=%lu runs=%lu samples=%d epochs=%ld\n",
                trainLastMs_,
                trainAvgMs,
                trainMaxMs_,
                trainCountRuns_,
                trainSamples,
                epochs);

  trainingInProgress_ = false;
  return buildTrainDonePayload(true, finalLoss, trainSamples, "ok", deviceId, pondId, uptimeMs);
}

bool FlRuntime::handleModelDownload(const String& msg, String& reason) {
  long incomingVersion = -1;
  int versionPos = msg.indexOf("VERSION:");
  if (versionPos >= 0) {
    int sep = msg.indexOf('|', versionPos);
    String versionText = (sep >= 0) ? msg.substring(versionPos + 8, sep) : msg.substring(versionPos + 8);
    long parsed = versionText.toInt();
    if (parsed > 0) incomingVersion = parsed;
  }

  if (incomingVersion > 0 && incomingVersion <= modelVersion_) {
    reason = "Reject global model downgrade/same version";
    return false;
  }

  int weightsPos = msg.indexOf("WEIGHTS:");
  if (weightsPos < 0) {
    reason = "Missing WEIGHTS";
    return false;
  }

  int sep = msg.indexOf('|', weightsPos);
  String weightsText = (sep >= 0) ? msg.substring(weightsPos + 8, sep) : msg.substring(weightsPos + 8);

  int wcrcPos = msg.indexOf("WCRC:");
  if (wcrcPos < 0) {
    reason = "Reject global weights: missing WCRC";
    return false;
  }

  int wcrcSep = msg.indexOf('|', wcrcPos);
  String wcrcText = (wcrcSep >= 0) ? msg.substring(wcrcPos + 5, wcrcSep) : msg.substring(wcrcPos + 5);
  wcrcText.trim();

  uint32_t gotCrc = (uint32_t)strtoul(wcrcText.c_str(), nullptr, 16);
  uint32_t calcCrc = crc32String(weightsText);
  if (gotCrc != calcCrc) {
    reason = "Reject global weights: CRC mismatch";
    return false;
  }

  float parsed[MODEL_DIM];
  int parsedCount = 0;
  if (!parseWeightsCsv(weightsText, parsed, MODEL_DIM, &parsedCount)) {
    reason = "Reject global weights: invalid dimension";
    return false;
  }

  if (parsedCount != MODEL_DIM) {
    reason = "Reject global weights: unsupported dimension";
    return false;
  }

  float oldLoss = estimateRecentLossWithWeights(weights_, 16);
  float newLoss = estimateRecentLossWithWeights(parsed, 16);
  if (oldLoss > 0.0f && newLoss > 0.0f && trainCount_ >= 8) {
    float tolerance = 0.02f + oldLoss * 0.35f;
    if (newLoss > oldLoss + tolerance) {
      reason = "Rollback global model: regression on local validation";
      return false;
    }
  }

  for (int i = 0; i < MODEL_DIM; ++i) {
    weights_[i] = parsed[i];
  }
  if (incomingVersion > 0) {
    modelVersion_ = incomingVersion;
  }
  saveToNvs();

  reason = "Applied global model";
  return true;
}

uint32_t FlRuntime::crc32Bytes(const uint8_t* data, size_t len) {
  uint32_t crc = 0xFFFFFFFFu;
  for (size_t i = 0; i < len; ++i) {
    crc ^= data[i];
    for (int j = 0; j < 8; ++j) {
      uint32_t mask = (uint32_t)(-(int32_t)(crc & 1u));
      crc = (crc >> 1) ^ (0xEDB88320u & mask);
    }
  }
  return ~crc;
}

uint32_t FlRuntime::crc32String(const String& s) {
  return crc32Bytes((const uint8_t*)s.c_str(), s.length());
}

bool FlRuntime::parseWeightsCsv(const String& csv, float* outWeights, int maxCount, int* parsedCount) {
  int start = 0;
  int idx = 0;
  while (start <= csv.length() && idx < maxCount) {
    int comma = csv.indexOf(',', start);
    String token = (comma >= 0) ? csv.substring(start, comma) : csv.substring(start);
    token.trim();
    if (token.length() > 0) {
      outWeights[idx] = token.toFloat();
      idx++;
    }
    if (comma < 0) break;
    start = comma + 1;
  }
  if (parsedCount != nullptr) {
    *parsedCount = idx;
  }
  return idx > 0;
}

String FlRuntime::weightsJsonArrayFrom(const float weights[MODEL_DIM]) {
  String out = "[";
  for (int i = 0; i < MODEL_DIM; ++i) {
    if (i > 0) out += ",";
    out += String(weights[i], 6);
  }
  out += "]";
  return out;
}

float FlRuntime::normalizeTemp(float tempC) {
  float clipped = tempC;
  if (clipped < 0.0f) clipped = 0.0f;
  if (clipped > 45.0f) clipped = 45.0f;
  return clipped / 45.0f;
}

float FlRuntime::predictTempNormWithWeights(const float weights[MODEL_DIM], const float x[MODEL_DIM]) {
  float y = 0.0f;
  for (int i = 0; i < MODEL_DIM; ++i) {
    y += weights[i] * x[i];
  }
  return y;
}

void FlRuntime::buildFeatures(int waterLevelPercent,
                              bool motorRunning,
                              int duty,
                              float prevTempNorm,
                              float outX[MODEL_DIM]) {
  float water = ((float)constrain(waterLevelPercent, 0, 100)) / 100.0f;
  float motor = motorRunning ? 1.0f : 0.0f;
  float dutyNorm = ((float)constrain(duty, 0, 1023)) / 1023.0f;

  outX[0] = 1.0f;
  outX[1] = water;
  outX[2] = motor;
  outX[3] = dutyNorm;
  outX[4] = constrain(prevTempNorm, 0.0f, 1.0f);
  outX[5] = water * dutyNorm;
  outX[6] = motor * dutyNorm;
  outX[7] = water * water;
}

float FlRuntime::estimateRecentLossWithWeights(const float weights[MODEL_DIM], int maxSamples) const {
  if (trainCount_ == 0 || maxSamples <= 0) {
    return -1.0f;
  }

  int n = maxSamples;
  if (n > trainCount_) n = trainCount_;

  float mse = 0.0f;
  for (int i = 0; i < n; ++i) {
    int idx = trainHead_ - 1 - i;
    if (idx < 0) idx += TRAIN_BUFFER_SIZE;
    const TrainSample& s = trainBuffer_[idx];
    float pred = predictTempNormWithWeights(weights, s.x);
    float err = pred - s.y;
    mse += err * err;
  }
  return mse / ((float)n);
}

void FlRuntime::saveToNvs() {
  if (!prefs_.begin("flmodel", false)) return;
  prefs_.putLong("version", modelVersion_);
  prefs_.putString("weights", weightsJsonArrayFrom(weights_));
  prefs_.end();
}

String FlRuntime::buildTrainDonePayload(bool success,
                                        float loss,
                                        long sampleCount,
                                        const char* reason,
                                        long deviceId,
                                        long pondId,
                                        unsigned long uptimeMs) const {
  String payload = "{";
  payload += "\"deviceId\":" + String(deviceId);
  payload += ",\"pondId\":" + String(pondId);
  payload += ",\"roundId\":" + String(currentRoundId_);
  payload += ",\"modelVersion\":" + String(modelVersion_);
  payload += ",\"success\":" + String(success ? "true" : "false");
  payload += ",\"loss\":" + String(loss, 6);
  payload += ",\"sampleCount\":" + String(sampleCount);
  payload += ",\"reason\":\"" + String(reason) + "\"";
  payload += ",\"shape\":[" + String(MODEL_DIM) + "]";
  payload += ",\"weights\":" + weightsJsonArrayFrom(weights_);
  payload += ",\"uptime_ms\":" + String(uptimeMs);
  payload += "}";
  return payload;
}
