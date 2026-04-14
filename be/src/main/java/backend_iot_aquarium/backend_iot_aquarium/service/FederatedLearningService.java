package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.Pond;
import backend_iot_aquarium.backend_iot_aquarium.repository.PondRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import java.util.zip.CRC32;

@Service
public class FederatedLearningService {

    private final FlRoundTracker flRoundTracker;
    private final PondRepository pondRepository;
    private final MqttService mqttService;
    private final AiGatewayService aiGatewayService;

    private final AtomicLong nextRoundId = new AtomicLong(1);

    @Value("${fl.round.default-deadline-seconds:900}")
    private long defaultDeadlineSeconds;

    @Value("${fl.round.default-min-clients:1}")
    private int defaultMinClients;

    @Value("${fl.round.default-min-samples:1}")
    private int defaultMinSamples;

    @Value("${fl.scheduler.auto-start-enabled:false}")
    private boolean autoStartEnabled;

    @Value("${fl.scheduler.auto-start-device-ids:}")
    private String autoStartDeviceIdsCsv;

    @Value("${fl.scheduler.auto-start-epochs:1}")
    private int autoStartEpochs;

    @Value("${fl.scheduler.auto-start-samples:32}")
    private int autoStartSamples;

    @Value("${fl.scheduler.check-delay-ms:30000}")
    private long aggregateCheckDelayMs;

    @Value("${fl.scheduler.auto-start-interval-ms:1800000}")
    private long autoStartIntervalMs;

    @Value("${fl.device.online-window-seconds:120}")
    private long onlineWindowSeconds;

    public FederatedLearningService(FlRoundTracker flRoundTracker,
                                    PondRepository pondRepository,
                                    MqttService mqttService,
                                    AiGatewayService aiGatewayService) {
        this.flRoundTracker = flRoundTracker;
        this.pondRepository = pondRepository;
        this.mqttService = mqttService;
        this.aiGatewayService = aiGatewayService;
    }

    @PostConstruct
    public void initRoundSequence() {
        long maxRoundId = flRoundTracker
                .allRounds()
                .stream()
                .mapToLong(FlRoundTracker.RoundState::getRoundId)
                .max()
                .orElse(0L);
        nextRoundId.set(maxRoundId + 1);
    }

    public Map<String, Object> startRound(Long requestedRoundId,
                                          Integer deadlineSeconds,
                                          Integer minClients,
                                          Integer minSamples,
                                          List<Long> deviceIds,
                                          Integer epochs,
                                          Integer samples) {
        long roundId = requestedRoundId != null ? requestedRoundId : nextRoundId.getAndIncrement();
        if (requestedRoundId != null) {
            nextRoundId.updateAndGet(v -> Math.max(v, requestedRoundId + 1));
        }

        if (flRoundTracker.exists(roundId)) {
            throw new IllegalArgumentException("Round already exists: " + roundId);
        }

        int resolvedDeadline = deadlineSeconds != null ? deadlineSeconds : (int) defaultDeadlineSeconds;
        int resolvedMinClients = minClients != null ? minClients : defaultMinClients;
        int resolvedMinSamples = minSamples != null ? minSamples : defaultMinSamples;
        int resolvedEpochs = epochs != null ? epochs : 1;
        int resolvedSamples = samples != null ? samples : 32;

        Set<Long> targets = resolveTargetDevices(deviceIds);
        FlRoundTracker.RoundState state = flRoundTracker.createRound(
                roundId,
                Instant.now().plusSeconds(Math.max(30, resolvedDeadline)),
                Math.max(1, resolvedMinClients),
                Math.max(1, resolvedMinSamples),
                targets
        );

        for (Long deviceId : targets) {
            String topic = "fl/model/" + deviceId + "/train/start";
            String payload = "ROUND:" + roundId
                    + "|EPOCHS:" + Math.max(1, resolvedEpochs)
                    + "|SAMPLES:" + Math.max(1, resolvedSamples);
            mqttService.publish(topic, payload);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("roundId", state.getRoundId());
        result.put("deadlineAt", state.getDeadlineAt().toString());
        result.put("minClients", state.getMinClients());
        result.put("minSamples", state.getMinSamples());
        result.put("targetDeviceIds", new ArrayList<>(state.getTargetDeviceIds()));
        return result;
    }

    public Map<String, Object> aggregateRound(long roundId) {
        FlRoundTracker.RoundState state = flRoundTracker.getRound(roundId);
        if (state == null) {
            throw new IllegalArgumentException("Round not found: " + roundId);
        }

        Map<String, Object> aggregateResponse = aiGatewayService.aggregateFlRound(
                roundId,
                state.getMinClients(),
                state.getMinSamples()
        );

        boolean success = Boolean.TRUE.equals(aggregateResponse.get("success"));
        Long version = asLong(aggregateResponse.get("version"));
        if (!success || version == null) {
            return aggregateResponse;
        }

        String checksum = String.valueOf(aggregateResponse.getOrDefault("checksum", ""));
        flRoundTracker.markAggregated(roundId, version, checksum);

        String weightsCsv = null;
        String weightsCrcHex = null;
        try {
            Map<String, Object> latestModel = aiGatewayService.getLatestFlModel();
            weightsCsv = extractWeightsCsv(latestModel);
            weightsCrcHex = weightsCsv == null ? null : crc32Hex(weightsCsv);
        } catch (Exception ignored) {
            // Keep backward-compatible payload without WEIGHTS when model fetch fails.
        }

        for (Long deviceId : state.getTargetDeviceIds()) {
            String topic = "fl/model/" + deviceId + "/download";
            String payload = "VERSION:" + version + "|CHECKSUM:" + checksum;
            if (weightsCsv != null && !weightsCsv.isBlank()) {
                payload = payload + "|WEIGHTS:" + weightsCsv;
                if (weightsCrcHex != null) {
                    payload = payload + "|WCRC:" + weightsCrcHex;
                }
            }
            mqttService.publish(topic, payload);
        }

        return aggregateResponse;
    }

    @Scheduled(fixedDelayString = "${fl.scheduler.check-delay-ms:30000}")
    public void aggregateDueRounds() {
        List<FlRoundTracker.RoundState> due = flRoundTracker.dueOpenRounds(Instant.now());
        for (FlRoundTracker.RoundState round : due) {
            try {
                aggregateRound(round.getRoundId());
            } catch (Exception ex) {
                flRoundTracker.markFailed(round.getRoundId(), ex.getMessage());
            }
        }
    }

    @Scheduled(
            fixedDelayString = "${fl.scheduler.auto-start-interval-ms:1800000}",
            initialDelayString = "${fl.scheduler.auto-start-initial-delay-ms:20000}"
    )
    public void autoStartRoundIfIdle() {
        if (!autoStartEnabled) {
            return;
        }

        boolean hasOpenRound = flRoundTracker
                .allRounds()
                .stream()
                .anyMatch(round -> round.getStatus() == FlRoundTracker.RoundStatus.OPEN);

        if (hasOpenRound) {
            return;
        }

        try {
            startRound(
                    null,
                    (int) defaultDeadlineSeconds,
                    defaultMinClients,
                    defaultMinSamples,
                    parseAutoStartDeviceIds(),
                    Math.max(1, autoStartEpochs),
                    Math.max(1, autoStartSamples)
            );
        } catch (Exception ignored) {
            // Keep scheduler resilient; next cycle can retry.
        }
    }

    @Value("${fl.scheduler.cleanup-interval-ms:86400000}")
    private long cleanupIntervalMs;

    @Value("${fl.scheduler.cleanup-retention-days:30}")
    private int cleanupRetentionDays;

    @Scheduled(
            fixedDelayString = "${fl.scheduler.cleanup-interval-ms:86400000}",
            initialDelayString = "${fl.scheduler.cleanup-initial-delay-ms:60000}"
    )
    public void cleanupOldRounds() {
        // Delete FL rounds older than retention period (default: 30 days)
        Instant cutoffTime = Instant.now().minus(Duration.ofDays(Math.max(1, cleanupRetentionDays)));
        
        List<Long> roundsToDelete = flRoundTracker.allRounds()
                .stream()
                .filter(round -> round.getCreatedAt().isBefore(cutoffTime))
                .map(FlRoundTracker.RoundState::getRoundId)
                .toList();
        
        if (roundsToDelete.isEmpty()) {
            return;
        }
        
        for (Long roundId : roundsToDelete) {
            try {
                flRoundTracker.deleteRound(roundId);
                // Also attempt to clean up updates and reports from AI service db
                // (if available through aiGatewayService)
            } catch (Exception ex) {
                // Log but don't fail the cleanup task
                System.err.printf("[FL] Failed to cleanup round %d: %s%n", roundId, ex.getMessage());
            }
        }
    }

    public List<Map<String, Object>> listRounds() {
        List<Map<String, Object>> result = new ArrayList<>();
        List<FlRoundTracker.RoundState> sorted = flRoundTracker.allRounds()
                .stream()
                .sorted(Comparator.comparing(FlRoundTracker.RoundState::getCreatedAt).reversed())
                .toList();
        for (FlRoundTracker.RoundState state : sorted) {
            result.add(toResponse(state));
        }
        return result;
    }

    public Map<String, Object> listRoundsHistory(String statusFilter, Integer page, Integer size) {
        int resolvedPage = page == null ? 0 : Math.max(0, page);
        int resolvedSize = size == null ? 10 : Math.max(1, Math.min(100, size));

        List<FlRoundTracker.RoundState> filtered = flRoundTracker
                .allRounds()
                .stream()
                .filter(round -> matchesStatusFilter(round, statusFilter))
                .sorted(Comparator.comparing(FlRoundTracker.RoundState::getCreatedAt).reversed())
                .toList();

        int totalItems = filtered.size();
        int totalPages = totalItems == 0 ? 0 : (int) Math.ceil((double) totalItems / resolvedSize);
        int from = Math.min(resolvedPage * resolvedSize, totalItems);
        int to = Math.min(from + resolvedSize, totalItems);

        List<Map<String, Object>> items = filtered
                .subList(from, to)
                .stream()
                .map(this::toResponse)
                .toList();

        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("items", items);
        response.put("page", resolvedPage);
        response.put("size", resolvedSize);
        response.put("totalItems", totalItems);
        response.put("totalPages", totalPages);
        response.put("statusFilter", normalizeStatusFilter(statusFilter));
        return response;
    }

    public Map<String, Object> getRound(long roundId) {
        FlRoundTracker.RoundState state = flRoundTracker.getRound(roundId);
        if (state == null) {
            throw new IllegalArgumentException("Round not found: " + roundId);
        }
        return toResponse(state);
    }

    public Map<String, Object> getRoundReports(long roundId) {
        return aiGatewayService.getFlReports(roundId);
    }

    public Map<String, Object> getRoundStats(long roundId) {
        FlRoundTracker.RoundState state = flRoundTracker.getRound(roundId);
        if (state == null) {
            throw new IllegalArgumentException("Round not found: " + roundId);
        }

        // Basic round statistics
        Map<String, Object> stats = new HashMap<>();
        stats.put("success", true);
        stats.put("roundId", state.getRoundId());
        stats.put("status", state.getStatus().name());
        stats.put("createdAt", state.getCreatedAt().toString());
        stats.put("deadlineAt", state.getDeadlineAt().toString());
        stats.put("aggregatedAt", state.getAggregatedAt() == null ? null : state.getAggregatedAt().toString());
        
        int totalTargets = state.getTargetDeviceIds().size();
        int totalUpdated = state.getUpdatedDeviceIds().size();
        int pending = totalTargets - totalUpdated;
        
        stats.put("targetDeviceCount", totalTargets);
        stats.put("updatedDeviceCount", totalUpdated);
        stats.put("pendingDeviceCount", Math.max(0, pending));
        stats.put("targetDeviceIds", new ArrayList<>(state.getTargetDeviceIds()));
        stats.put("updatedDeviceIds", new ArrayList<>(state.getUpdatedDeviceIds()));
        stats.put("minClients", state.getMinClients());
        stats.put("minSamples", state.getMinSamples());
        stats.put("aggregatedVersion", state.getAggregatedVersion());
        stats.put("checksum", state.getChecksum());
        
        if (state.getLastError() != null) {
            stats.put("lastError", state.getLastError());
        }

        return stats;
    }

    public Map<String, Object> getLatestModel() {
        Map<String, Object> latestModel = aiGatewayService.getLatestFlModel();
        if (latestModel == null || latestModel.isEmpty()) {
            return Map.of(
                    "success", false,
                    "error", "Chưa có model global active",
                    "statusCode", 404
            );
        }

        return latestModel;
    }

    public Map<String, Object> getRuntimeStatus() {
        List<FlRoundTracker.RoundState> openRounds = flRoundTracker
                .allRounds()
                .stream()
                .filter(round -> round.getStatus() == FlRoundTracker.RoundStatus.OPEN)
                .toList();

        List<Long> openRoundIds = openRounds.stream().map(FlRoundTracker.RoundState::getRoundId).toList();

        return Map.of(
                "success", true,
                "autoStartEnabled", autoStartEnabled,
                "aggregateCheckDelayMs", aggregateCheckDelayMs,
                "autoStartIntervalMs", autoStartIntervalMs,
                "defaultDeadlineSeconds", defaultDeadlineSeconds,
                "openRounds", openRoundIds,
                "openRoundCount", openRoundIds.size()
        );
    }

    public Map<String, Object> getOnlineDevices() {
        LocalDateTime now = LocalDateTime.now();
        Duration onlineWindow = Duration.ofSeconds(Math.max(30, onlineWindowSeconds));
        List<Map<String, Object>> items = new ArrayList<>();

        for (Pond pond : pondRepository.findAll()) {
            Long deviceId = pond.getDeviceId() != null ? pond.getDeviceId() : pond.getId();
            if (deviceId == null || deviceId <= 0) {
                continue;
            }

            LocalDateTime lastTelemetryAt = pond.getLastTelemetryAt();
            if (lastTelemetryAt == null) {
                continue;
            }

            Duration age = Duration.between(lastTelemetryAt, now);
            if (age.isNegative() || age.compareTo(onlineWindow) <= 0) {
                Map<String, Object> row = new HashMap<>();
                row.put("pondId", pond.getId());
                row.put("pondName", pond.getName());
                row.put("deviceId", deviceId);
                row.put("lastTelemetryAt", lastTelemetryAt.toString());
                row.put("secondsSinceLastTelemetry", Math.max(0, age.getSeconds()));
                items.add(row);
            }
        }

        items.sort(Comparator.comparing(item -> asLong(item.get("deviceId")), Comparator.nullsLast(Long::compareTo)));

        return Map.of(
                "success", true,
                "onlineWindowSeconds", onlineWindow.getSeconds(),
                "count", items.size(),
                "items", items
        );
    }

    private Map<String, Object> toResponse(FlRoundTracker.RoundState state) {
        Map<String, Object> data = new HashMap<>();
        data.put("roundId", state.getRoundId());
        data.put("status", state.getStatus().name());
        data.put("createdAt", state.getCreatedAt().toString());
        data.put("deadlineAt", state.getDeadlineAt().toString());
        data.put("minClients", state.getMinClients());
        data.put("minSamples", state.getMinSamples());
        data.put("targetDeviceIds", new ArrayList<>(state.getTargetDeviceIds()));
        data.put("updatedDeviceIds", new ArrayList<>(state.getUpdatedDeviceIds()));
        data.put("aggregatedAt", state.getAggregatedAt() == null ? null : state.getAggregatedAt().toString());
        data.put("aggregatedVersion", state.getAggregatedVersion());
        data.put("checksum", state.getChecksum());
        data.put("lastError", state.getLastError());
        return data;
    }

    private boolean matchesStatusFilter(FlRoundTracker.RoundState round, String statusFilter) {
        String normalized = normalizeStatusFilter(statusFilter);
        if ("ALL".equals(normalized)) {
            return true;
        }
        return round.getStatus().name().equals(normalized);
    }

    private String normalizeStatusFilter(String statusFilter) {
        if (statusFilter == null || statusFilter.isBlank()) {
            return "ALL";
        }
        String normalized = statusFilter.trim().toUpperCase();
        if ("OPEN".equals(normalized) || "AGGREGATED".equals(normalized) || "FAILED".equals(normalized)) {
            return normalized;
        }
        return "ALL";
    }

    private Set<Long> resolveTargetDevices(List<Long> requestedDeviceIds) {
        if (requestedDeviceIds != null && !requestedDeviceIds.isEmpty()) {
            return new LinkedHashSet<>(requestedDeviceIds);
        }

        Set<Long> targets = new LinkedHashSet<>();
        for (Pond pond : pondRepository.findAll()) {
            Long value = pond.getDeviceId() != null ? pond.getDeviceId() : pond.getId();
            if (value != null) {
                targets.add(value);
            }
        }
        if (targets.isEmpty()) {
            throw new IllegalStateException("No pond/device available to start FL round");
        }
        return targets;
    }

    private List<Long> parseAutoStartDeviceIds() {
        if (autoStartDeviceIdsCsv == null || autoStartDeviceIdsCsv.isBlank()) {
            return null;
        }

        List<Long> result = new ArrayList<>();
        String[] parts = autoStartDeviceIdsCsv.split(",");
        for (String part : parts) {
            String value = part == null ? "" : part.trim();
            if (value.isBlank()) {
                continue;
            }
            try {
                long parsed = Long.parseLong(value);
                if (parsed > 0) {
                    result.add(parsed);
                }
            } catch (NumberFormatException ignored) {
                // Skip invalid ids to avoid stopping auto scheduler.
            }
        }

        return result.isEmpty() ? null : result;
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

    @SuppressWarnings("unchecked")
    private String extractWeightsCsv(Map<String, Object> latestModel) {
        if (latestModel == null) {
            return null;
        }

        Object payloadObj = latestModel.get("payload");
        if (!(payloadObj instanceof Map<?, ?> payloadMap)) {
            return null;
        }

        Object weightsObj = payloadMap.get("weights");
        if (!(weightsObj instanceof List<?> weightsList) || weightsList.isEmpty()) {
            return null;
        }

        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < weightsList.size(); i++) {
            if (i > 0) sb.append(',');
            Object v = weightsList.get(i);
            if (v instanceof Number n) {
                sb.append(n.doubleValue());
            } else {
                sb.append(v);
            }
        }
        return sb.toString();
    }

    private String crc32Hex(String text) {
        CRC32 crc32 = new CRC32();
        crc32.update(text.getBytes());
        long value = crc32.getValue();
        return String.format("%08X", value);
    }
}
