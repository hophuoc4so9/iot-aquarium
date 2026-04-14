#pragma once

#include <Arduino.h>
#include <PubSubClient.h>

void mqttEnsureConnected(PubSubClient& mqttClient,
                         const String& clientId,
                         const char* sharedCmdTopic,
                         const char* sharedModeTopic,
                         const String& pondCmdTopic,
                         const String& pondModeTopic,
                         const String& flTrainStartTopic,
                         const String& flModelDownloadTopic,
                         bool autoMode);
