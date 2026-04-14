#pragma once

#include <Arduino.h>

enum MotorDirection {
  MOTOR_STOPPED = 0,
  MOTOR_FORWARD = 1,
  MOTOR_BACKWARD = 2,
};

class MotorRuntime {
public:
  MotorRuntime(uint8_t pwmPin,
               uint8_t rPwmPin,
               uint8_t lPwmPin,
               int ledcChannel,
               uint32_t ledcFreq,
               uint8_t ledcResolutionBits);

  void init();
  void forward(uint32_t duty);
  void backward(uint32_t duty);
  void stop();
  void applyDuty(uint32_t duty) const;

  bool running() const;
  unsigned long startMillis() const;
  MotorDirection direction() const;

private:
  uint8_t pwmPin_;
  uint8_t rPwmPin_;
  uint8_t lPwmPin_;
  int ledcChannel_;
  uint32_t ledcFreq_;
  uint8_t ledcResolutionBits_;

  bool running_;
  unsigned long startMillis_;
  MotorDirection direction_;
};
