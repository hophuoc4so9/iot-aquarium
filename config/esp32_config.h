// Central ESP32 build-time configuration header
// Edit values here or generate this file from global.properties as needed.
#ifndef ESP32_CONFIG_H
#define ESP32_CONFIG_H

// MQTT
#define MQTT_SERVER_IP "10.30.233.17"
#define MQTT_SERVER_PORT 1883

// Backend API base (optional, for firmware to call backend)
#define BACKEND_API_BASE "http://10.30.233.17:8080"

// Default topics
#define MQTT_TOPIC_CMD "aquarium/pump/cmd"
#define MQTT_TOPIC_MODE "aquarium/pump/mode"
#define MQTT_TOPIC_STATUS "aquarium/pump/status"

#endif // ESP32_CONFIG_H
