#include "mqtt_runtime.h"

void mqttEnsureConnected(PubSubClient& mqttClient,
                         const String& clientId,
                         const char* sharedCmdTopic,
                         const char* sharedModeTopic,
                         const String& pondCmdTopic,
                         const String& pondModeTopic,
                         const String& flTrainStartTopic,
                         const String& flModelDownloadTopic,
                         bool autoMode) {
  while (!mqttClient.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println("connected");
      mqttClient.subscribe(sharedCmdTopic);
      mqttClient.subscribe(sharedModeTopic);
      mqttClient.subscribe(pondCmdTopic.c_str());
      mqttClient.subscribe(pondModeTopic.c_str());
      mqttClient.subscribe(flTrainStartTopic.c_str());
      mqttClient.subscribe(flModelDownloadTopic.c_str());
      mqttClient.publish(sharedModeTopic, autoMode ? "AUTO" : "MANUAL");
    } else {
      Serial.print("failed, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" try again in 2 seconds");
      delay(2000);
    }
  }
}
