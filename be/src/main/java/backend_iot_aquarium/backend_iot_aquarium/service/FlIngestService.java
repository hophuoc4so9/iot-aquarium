package backend_iot_aquarium.backend_iot_aquarium.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
public class FlIngestService {

    private final ObjectMapper objectMapper;
    private final AiGatewayService aiGatewayService;
    private final FlRoundTracker flRoundTracker;

    public FlIngestService(ObjectMapper objectMapper,
                           AiGatewayService aiGatewayService,
                           FlRoundTracker flRoundTracker) {
        this.objectMapper = objectMapper;
        this.aiGatewayService = aiGatewayService;
        this.flRoundTracker = flRoundTracker;
    }

    public Map<String, Object> ingestHttpUpdate(Map<String, Object> body) {
        Long roundId = asLong(body.get("roundId"));
        Long deviceId = asLong(body.get("deviceId"));
        if (roundId != null && deviceId != null) {
            flRoundTracker.markDeviceUpdated(roundId, deviceId);
        }
        return aiGatewayService.uploadFlUpdate(body);
    }

    public Map<String, Object> ingestMqttReport(String topic, String payload) {
        try {
            Map<String, Object> report = objectMapper.readValue(payload, new TypeReference<>() {});
            report.put("topic", topic);

            Long roundId = asLong(report.get("roundId"));
            Long deviceId = asLong(report.get("deviceId"));
            if (roundId != null && deviceId != null) {
                flRoundTracker.markDeviceUpdated(roundId, deviceId);
            }

            if (report.containsKey("weights") && report.containsKey("shape")) {
                aiGatewayService.uploadFlUpdate(report);
            }

            return aiGatewayService.uploadFlReport(report);
        } catch (Exception ex) {
            Map<String, Object> res = new HashMap<>();
            res.put("success", false);
            res.put("error", ex.getMessage());
            return res;
        }
    }

    private Long asLong(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.longValue();
        }
        try {
            return Long.parseLong(String.valueOf(value));
        } catch (NumberFormatException ex) {
            return null;
        }
    }
}
