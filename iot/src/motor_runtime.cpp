#include "motor_runtime.h"

MotorRuntime::MotorRuntime(uint8_t pwmPin,
                           uint8_t rPwmPin,
                           uint8_t lPwmPin,
                           int ledcChannel,
                           uint32_t ledcFreq,
                           uint8_t ledcResolutionBits)
    : pwmPin_(pwmPin),
      rPwmPin_(rPwmPin),
      lPwmPin_(lPwmPin),
      ledcChannel_(ledcChannel),
      ledcFreq_(ledcFreq),
      ledcResolutionBits_(ledcResolutionBits),
      running_(false),
      startMillis_(0),
      direction_(MOTOR_STOPPED) {}

void MotorRuntime::init() {
  ledcSetup(ledcChannel_, ledcFreq_, ledcResolutionBits_);
  ledcAttachPin(pwmPin_, ledcChannel_);
  pinMode(rPwmPin_, OUTPUT);
  pinMode(lPwmPin_, OUTPUT);
  digitalWrite(rPwmPin_, LOW);
  digitalWrite(lPwmPin_, LOW);
}

void MotorRuntime::forward(uint32_t duty) {
  digitalWrite(rPwmPin_, HIGH);
  digitalWrite(lPwmPin_, LOW);
  applyDuty(duty);
  running_ = true;
  direction_ = MOTOR_FORWARD;
  startMillis_ = millis();
}

void MotorRuntime::backward(uint32_t duty) {
  digitalWrite(rPwmPin_, LOW);
  digitalWrite(lPwmPin_, HIGH);
  applyDuty(duty);
  running_ = true;
  direction_ = MOTOR_BACKWARD;
  startMillis_ = millis();
}

void MotorRuntime::stop() {
  digitalWrite(rPwmPin_, LOW);
  digitalWrite(lPwmPin_, LOW);
  applyDuty(0);
  running_ = false;
  direction_ = MOTOR_STOPPED;
}

void MotorRuntime::applyDuty(uint32_t duty) const {
  ledcWrite(ledcChannel_, duty);
}

bool MotorRuntime::running() const {
  return running_;
}

unsigned long MotorRuntime::startMillis() const {
  return startMillis_;
}

MotorDirection MotorRuntime::direction() const {
  return direction_;
}
