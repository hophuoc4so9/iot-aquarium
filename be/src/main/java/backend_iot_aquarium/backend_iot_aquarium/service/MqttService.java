package backend_iot_aquarium.backend_iot_aquarium.service;

import org.eclipse.paho.client.mqttv3.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;

@Service
public class MqttService {

    @Value("${mqtt.broker}")
    private String broker;

    @Value("${mqtt.clientId}")
    private String clientId;

    @Value("${mqtt.topic}")
    private String topic;

    @Value("${mqtt.pond-topic-prefix:nckh/iot-aquarium/esp32/pond/}")
    private String pondTopicPrefix;

    private MqttClient client;

    private final TelemetryService telemetryService;
    private final AlertService alertService;
    private final FlIngestService flIngestService;

    public MqttService(TelemetryService telemetryService,
                       AlertService alertService,
                       FlIngestService flIngestService) {
        this.telemetryService = telemetryService;
        this.alertService = alertService;
        this.flIngestService = flIngestService;
    }

    @PostConstruct
    public void init() {
        try {
            client = new MqttClient(broker, clientId + "-" + System.currentTimeMillis());
            MqttConnectOptions opts = new MqttConnectOptions();
            opts.setAutomaticReconnect(true);
            // Keep session so broker can retain subscriptions across reconnects.
            opts.setCleanSession(false);

            client.setCallback(new MqttCallbackExtended() {
                @Override
                public void connectComplete(boolean reconnect, String serverURI) {
                    subscribeAll();
                }

                @Override
                public void connectionLost(Throwable cause) { }

                @Override
                public void messageArrived(String topic, MqttMessage message) throws Exception {
                    String payload = new String(message.getPayload());
                    if (isTelemetryTopic(topic)) {
                        telemetryService.processIncoming(topic, payload);
                    } else if (topic.startsWith("fl/model/") || topic.startsWith("fl/metrics/")) {
                        flIngestService.ingestMqttReport(topic, payload);
                    }
                }

                @Override
                public void deliveryComplete(IMqttDeliveryToken token) { }
            });

            client.connect(opts);
            subscribeAll();
        } catch (MqttException e) {
            e.printStackTrace();
        }
    }

    private void subscribeAll() {
        try {
            if (client == null || !client.isConnected()) {
                return;
            }
            client.subscribe(topic);
            client.subscribe(pondTopicPrefix + "+/telemetry");
            client.subscribe("fl/model/+/train/done");
            client.subscribe("fl/metrics/+/report");
        } catch (MqttException e) {
            e.printStackTrace();
        }
    }

    private boolean isTelemetryTopic(String incomingTopic) {
        if (incomingTopic == null || incomingTopic.isBlank()) {
            return false;
        }
        if (incomingTopic.equals(topic)) {
            return true;
        }
        return incomingTopic.startsWith(pondTopicPrefix) && incomingTopic.endsWith("/telemetry");
    }

    public void publish(String topic, String payload) {
        try {
            if (client != null && client.isConnected()) {
                client.publish(topic, new MqttMessage(payload.getBytes()));
            }
        } catch (MqttException e) { e.printStackTrace(); }
    }
}
