package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.Telemetry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class AlertService {

    @Value("${alerts.temperature.high}")
    private double highTemp;

    @Value("${alerts.temperature.low}")
    private double lowTemp;

    @Value("${alerts.ph.high}")
    private double highPh;

    @Value("${alerts.ph.low}")
    private double lowPh;

    private final MqttService mqttService;
    private final AiGatewayService aiGatewayService;

    public AlertService(@Lazy MqttService mqttService,
                        @Lazy AiGatewayService aiGatewayService) {
        this.mqttService = mqttService;
        this.aiGatewayService = aiGatewayService;
    }

    public void evaluate(Telemetry t) {
        // Check for float switch error: floatLow OFF && floatHigh ON (abnormal)
        checkFloatSwitchError(t);

        // Temperature alerts (if present)
        if (t.getTemperature() != null) {
            if (t.getTemperature() > highTemp) {
                String msg = "ALERT: temperature high=" + t.getTemperature();
                System.out.println(msg);
                mqttService.publish("alerts/temperature", msg);
            } else if (t.getTemperature() < lowTemp) {
                String msg = "ALERT: temperature low=" + t.getTemperature();
                System.out.println(msg);
                mqttService.publish("alerts/temperature", msg);
            }
        }

        // pH alerts (if present)
        if (t.getPh() != null) {
            if (t.getPh() > highPh) {
                String msg = "ALERT: pH high=" + t.getPh() + " (alkaline)";
                System.out.println(msg);
                mqttService.publish("alerts/ph", msg);
            } else if (t.getPh() < lowPh) {
                String msg = "ALERT: pH low=" + t.getPh() + " (acidic)";
                System.out.println(msg);
                mqttService.publish("alerts/ph", msg);
            }
        }

        // Water level alert: if floatLow is present and false -> water is below minimum
        if (t.getFloatLow() != null) {
            if (!t.getFloatLow()) {
                String msg = "ALERT: water level LOW (floatLow=false)";
                System.out.println(msg);
                mqttService.publish("alerts/waterlevel", msg);
            }
        }

        // also check for high water level (floatHigh == true)
        alertIfHighWater(t);
    }

    /**
     * Check for float switch error condition:
     * floatLow = false (OFF) && floatHigh = true (ON) is abnormal
     */
    private void checkFloatSwitchError(Telemetry t) {
        if (t.getFloatLow() != null && t.getFloatHigh() != null) {
            if (!t.getFloatLow() && t.getFloatHigh()) {
                String msg = "ALERT: Float switch ERROR - floatLow=OFF but floatHigh=ON (abnormal state)";
                System.out.println(msg);
                mqttService.publish("alerts/float_error", msg);
            }
        }
    }

    /**
     * Public helper to alert when the high float is triggered (tank is full).
     * This is kept as a separate method so callers can trigger only high-level checks if needed.
     */
    public void alertIfHighWater(Telemetry t) {
        if (t.getFloatHigh() != null && t.getFloatHigh()) {
            String msg = "ALERT: water level HIGH (floatHigh=true)";
            System.out.println(msg);
            mqttService.publish("alerts/waterlevel", msg);
        }
    }

    /**
     * Helper cho controller / mobile app:
     * gọi AI service /ponds/{id}/alerts và trả về JSON.
     * pondThresholds / fishThresholds có thể null.
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> getAiAlertsForPond(Long pondId,
                                                  Map<String, Object> pondThresholds,
                                                  Map<String, Object> fishThresholds) {
        Map<String, Object> resp = aiGatewayService.instantAlerts(pondId, pondThresholds, fishThresholds);

        // Tuỳ chọn: log thêm các cảnh báo DANGER lên MQTT
        Object alertsObj = resp.get("alerts");
        if (alertsObj instanceof List) {
            List<?> alerts = (List<?>) alertsObj;
            for (Object a : alerts) {
                if (a instanceof Map<?, ?> map) {
                    Object level = map.get("level");
                    Object message = map.get("message");
                    if ("DANGER".equals(level) && message != null) {
                        String msg = "AI-DANGER: " + message;
                        System.out.println(msg);
                        mqttService.publish("alerts/ai", msg);
                    }
                }
            }
        }

        return resp;
    }
}
