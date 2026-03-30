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

    private MqttClient client;

    private final TelemetryService telemetryService;
    private final AlertService alertService;

    public MqttService(TelemetryService telemetryService, AlertService alertService) {
        this.telemetryService = telemetryService;
        this.alertService = alertService;
    }

    @PostConstruct
    public void init() {
        try {
            client = new MqttClient(broker, clientId + "-" + System.currentTimeMillis());
            MqttConnectOptions opts = new MqttConnectOptions();
            opts.setAutomaticReconnect(true);
            // use setCleanSession for this client version
            opts.setCleanSession(true);
            client.connect(opts);

            client.setCallback(new MqttCallback() {
                @Override
                public void connectionLost(Throwable cause) { }

                @Override
                public void messageArrived(String topic, MqttMessage message) throws Exception {
                    String payload = new String(message.getPayload());
                    telemetryService.processIncoming(payload);
                }

                @Override
                public void deliveryComplete(IMqttDeliveryToken token) { }
            });

            client.subscribe(topic);
        } catch (MqttException e) {
            e.printStackTrace();
        }
    }

    public void publish(String topic, String payload) {
        try {
            if (client != null && client.isConnected()) {
                client.publish(topic, new MqttMessage(payload.getBytes()));
            }
        } catch (MqttException e) { e.printStackTrace(); }
    }
}
