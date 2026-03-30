package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.Pond;
import backend_iot_aquarium.backend_iot_aquarium.model.Telemetry;
import backend_iot_aquarium.backend_iot_aquarium.repository.PondRepository;
import backend_iot_aquarium.backend_iot_aquarium.repository.TelemetryRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@Service
public class TelemetryService {

    private final TelemetryRepository repository;
    private final AlertService alertService;
    private final SimpMessagingTemplate messagingTemplate;
    private final PondRepository pondRepository;
    private final ObjectMapper mapper = new ObjectMapper();

    public TelemetryService(
            TelemetryRepository repository,
            AlertService alertService,
            SimpMessagingTemplate messagingTemplate,
            PondRepository pondRepository
    ) {
        this.repository = repository;
        this.alertService = alertService;
        this.messagingTemplate = messagingTemplate;
        this.pondRepository = pondRepository;
    }

    public void processIncoming(String payload) {
        try {
            JsonNode n = mapper.readTree(payload);
            Telemetry t = new Telemetry();
            // New standardized fields from ESP32 firmware
            if (n.has("deviceId")) t.setDeviceId(n.get("deviceId").asText());
            JsonNode pondNode = n.has("pondId") ? n.get("pondId") : n.get("pond_id");
            if (pondNode != null && !pondNode.isNull()) {
                long pondId = pondNode.asLong();
                t.setPondId(pondId);

                // Auto-create Pond nếu chưa có, ưu tiên dùng đúng ID theo pondId từ telemetry
                String autoName = "Ao " + pondId + " (auto)";
                boolean exists = pondRepository.existsById(pondId);

                if (!exists) {
                    Pond p = new Pond();
                    p.setId(pondId);
                    p.setName(autoName);
                    p.setArea(null);
                    p.setFishType(null);
                    p.setStockingDate(null);
                    p.setDensity(null);
                    p.setNote("Tạo tự động từ telemetry, pondId=" + pondId + ", deviceId=" + t.getDeviceId());
                    pondRepository.save(p);
                }
            }
            if (n.has("temperature")) t.setTemperature(n.get("temperature").asDouble());
            if (n.has("ph")) t.setPh(n.get("ph").asDouble());
            if (n.has("waterLevel")) t.setWaterLevel(n.get("waterLevel").asDouble());
            if (n.has("waterLevelPercent") && !n.has("waterLevel")) {
                // fallback: map waterLevelPercent vào waterLevel nếu không có field cũ
                t.setWaterLevel(n.get("waterLevelPercent").asDouble());
            }
            // ESP32-specific fields (from your main.cpp status JSON)
            if (n.has("floatHigh")) t.setFloatHigh(n.get("floatHigh").asBoolean());
            if (n.has("floatLow")) t.setFloatLow(n.get("floatLow").asBoolean());
            if (n.has("motorRunning")) t.setMotorRunning(n.get("motorRunning").asBoolean());
            if (n.has("duty")) t.setDuty(n.get("duty").asInt());
            if (n.has("mode")) t.setMode(n.get("mode").asText());
            if (n.has("direction")) t.setDirection(n.get("direction").asText());
            if (n.has("uptime_ms")) t.setUptimeMs(n.get("uptime_ms").asLong());
            t.setRawPayload(payload);
            repository.save(t);
            alertService.evaluate(t);

            // Broadcast to WebSocket clients
            broadcastTelemetry(t, payload);
        } catch (IOException e) {
            // if not JSON, still save raw
            Telemetry t = new Telemetry();
            t.setRawPayload(payload);
            repository.save(t);
        }
    }

    private void broadcastTelemetry(Telemetry t, String rawPayload) {
        try {
            // Create message in format expected by web client: { topic, data }
            Map<String, Object> message = new HashMap<>();
            message.put("topic", "esp32/telemetry");
            message.put("data", rawPayload);

            // Send to /topic/stream
            messagingTemplate.convertAndSend("/topic/stream", message);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
