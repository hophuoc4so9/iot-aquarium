package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.Pond;
import backend_iot_aquarium.backend_iot_aquarium.model.Telemetry;
import backend_iot_aquarium.backend_iot_aquarium.repository.DeviceOwnershipRepository;
import backend_iot_aquarium.backend_iot_aquarium.repository.PondRepository;
import backend_iot_aquarium.backend_iot_aquarium.repository.TelemetryRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Service
public class TelemetryService {

    private final TelemetryRepository repository;
    private final AlertService alertService;
    private final SimpMessagingTemplate messagingTemplate;
    private final PondRepository pondRepository;
    private final DeviceOwnershipRepository deviceOwnershipRepository;
    private final ObjectMapper mapper = new ObjectMapper();

    public TelemetryService(
            TelemetryRepository repository,
            AlertService alertService,
            SimpMessagingTemplate messagingTemplate,
            PondRepository pondRepository,
            DeviceOwnershipRepository deviceOwnershipRepository
    ) {
        this.repository = repository;
        this.alertService = alertService;
        this.messagingTemplate = messagingTemplate;
        this.pondRepository = pondRepository;
        this.deviceOwnershipRepository = deviceOwnershipRepository;
    }

    public void processIncoming(String topic, String payload) {
        try {
            JsonNode n = mapper.readTree(payload);
            Telemetry t = new Telemetry();
            // New standardized fields from ESP32 firmware
            JsonNode deviceNode = n.has("deviceId") ? n.get("deviceId") : null;
            if (deviceNode != null && !deviceNode.isNull()) {
                Long deviceId = parseLongNode(deviceNode);
                if (deviceId != null) {
                    t.setDeviceId(deviceId);
                }
            }
            JsonNode pondNode = n.has("pondId") ? n.get("pondId") : n.get("pond_id");
            if (pondNode != null && !pondNode.isNull()) {
                long pondId = pondNode.asLong();
                t.setPondId(pondId);
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

            // Ignore repeated stale snapshots (often from retained/shared-broker messages)
            // so they don't refresh "online" timestamps incorrectly.
            if (isStaleDuplicate(t)) {
                return;
            }

            repository.save(t);

            // Đồng bộ ao theo telemetry mới nhất: tự tạo ao nếu chưa có và cập nhật snapshot trạng thái.
            upsertPondFromTelemetry(t);

            alertService.evaluate(t);

            // Broadcast to WebSocket clients
            broadcastTelemetry(topic, payload);
        } catch (IOException e) {
            // if not JSON, still save raw
            Telemetry t = new Telemetry();
            t.setRawPayload(payload);
            repository.save(t);
        }
    }

    private void upsertPondFromTelemetry(Telemetry t) {
        if (t.getPondId() == null) {
            return;
        }

        Long mqttPondId = t.getPondId();
        String autoName = "Ao " + mqttPondId + " (auto)";

        Pond pond = pondRepository.findByDeviceId(mqttPondId)
                // Backward compatibility: nếu đã có ao cũ dùng id trùng pondId MQTT thì vẫn tận dụng
                .or(() -> pondRepository.findById(mqttPondId))
                .orElseGet(() -> {
            Pond p = new Pond();
            p.setDeviceId(mqttPondId);
            p.setName(autoName);
            p.setNote("Tạo tự động từ telemetry, pondId=" + mqttPondId + ", deviceId=" + t.getDeviceId());
            return p;
        });

        if (pond.getDeviceId() == null) {
            pond.setDeviceId(mqttPondId);
        }

        if (pond.getName() == null || pond.getName().isBlank()) {
            pond.setName(autoName);
        }

        if (t.getDeviceId() != null && (pond.getOwnerUsername() == null || pond.getOwnerUsername().isBlank())) {
            deviceOwnershipRepository.findByDeviceId(t.getDeviceId())
                    .ifPresent(rule -> pond.setOwnerUsername(rule.getOwnerUsername()));
        }

        if (t.getDeviceId() != null) {
            pond.setLastDeviceId(t.getDeviceId());
        }
        if (t.getTemperature() != null) {
            pond.setLastTemperature(t.getTemperature());
        }
        if (t.getPh() != null) {
            pond.setLastPh(t.getPh());
        }
        if (t.getWaterLevel() != null) {
            pond.setLastWaterLevel(t.getWaterLevel());
        }
        if (t.getFloatHigh() != null) {
            pond.setLastFloatHigh(t.getFloatHigh());
        }
        if (t.getFloatLow() != null) {
            pond.setLastFloatLow(t.getFloatLow());
        }
        if (t.getMotorRunning() != null) {
            pond.setLastMotorRunning(t.getMotorRunning());
        }
        if (t.getDuty() != null) {
            pond.setLastDuty(t.getDuty());
        }
        if (t.getMode() != null && !t.getMode().isBlank()) {
            pond.setLastMode(t.getMode());
        }
        if (t.getDirection() != null && !t.getDirection().isBlank()) {
            pond.setLastDirection(t.getDirection());
        }
        if (t.getUptimeMs() != null) {
            pond.setLastUptimeMs(t.getUptimeMs());
        }

        pond.setLastTelemetryAt(LocalDateTime.now());
        pondRepository.save(pond);
    }

    private void broadcastTelemetry(String topic, String rawPayload) {
        try {
            // Create message in format expected by web client: { topic, data }
            Map<String, Object> message = new HashMap<>();
            message.put("topic", topic);
            message.put("data", rawPayload);

            // Send to /topic/stream
            messagingTemplate.convertAndSend("/topic/stream", message);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private boolean isStaleDuplicate(Telemetry incoming) {
        Telemetry latest;
        if (incoming.getPondId() != null) {
            latest = repository.findTopByPondIdOrderByTimestampDesc(incoming.getPondId());
        } else {
            latest = repository.findTopByOrderByTimestampDesc();
        }
        if (latest == null) {
            return false;
        }

        String incomingRaw = incoming.getRawPayload();
        String latestRaw = latest.getRawPayload();
        if (incomingRaw == null || latestRaw == null || !incomingRaw.equals(latestRaw)) {
            return false;
        }

        Long incomingUptime = incoming.getUptimeMs();
        Long latestUptime = latest.getUptimeMs();
        return incomingUptime != null && latestUptime != null && incomingUptime.equals(latestUptime);
    }

    private Long parseLongNode(JsonNode node) {
        if (node.isNumber()) {
            return node.asLong();
        }
        if (node.isTextual()) {
            String text = node.asText().trim();
            if (text.isEmpty()) {
                return null;
            }
            try {
                return Long.parseLong(text);
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }
}
