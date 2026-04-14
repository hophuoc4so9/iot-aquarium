package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.FlRoundStateEntity;
import backend_iot_aquarium.backend_iot_aquarium.repository.FlRoundStateRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Component
public class FlRoundTracker {

    public enum RoundStatus {
        OPEN,
        AGGREGATED,
        FAILED
    }

    public static class RoundState {
        private final long roundId;
        private final Instant createdAt;
        private final Instant deadlineAt;
        private final int minClients;
        private final int minSamples;
        private final Set<Long> targetDeviceIds;
        private final Set<Long> updatedDeviceIds = ConcurrentHashMap.newKeySet();

        private volatile RoundStatus status = RoundStatus.OPEN;
        private volatile Instant aggregatedAt;
        private volatile Long aggregatedVersion;
        private volatile String checksum;
        private volatile String lastError;

        public RoundState(long roundId,
                          Instant createdAt,
                          Instant deadlineAt,
                          int minClients,
                          int minSamples,
                          Set<Long> targetDeviceIds) {
            this.roundId = roundId;
            this.createdAt = createdAt;
            this.deadlineAt = deadlineAt;
            this.minClients = minClients;
            this.minSamples = minSamples;
            this.targetDeviceIds = targetDeviceIds;
        }

        public long getRoundId() {
            return roundId;
        }

        public Instant getCreatedAt() {
            return createdAt;
        }

        public Instant getDeadlineAt() {
            return deadlineAt;
        }

        public int getMinClients() {
            return minClients;
        }

        public int getMinSamples() {
            return minSamples;
        }

        public Set<Long> getTargetDeviceIds() {
            return targetDeviceIds;
        }

        public Set<Long> getUpdatedDeviceIds() {
            return updatedDeviceIds;
        }

        public RoundStatus getStatus() {
            return status;
        }

        public Instant getAggregatedAt() {
            return aggregatedAt;
        }

        public Long getAggregatedVersion() {
            return aggregatedVersion;
        }

        public String getChecksum() {
            return checksum;
        }

        public String getLastError() {
            return lastError;
        }

        private void setStatus(RoundStatus status) {
            this.status = status;
        }

        private void setAggregatedAt(Instant aggregatedAt) {
            this.aggregatedAt = aggregatedAt;
        }

        private void setAggregatedVersion(Long aggregatedVersion) {
            this.aggregatedVersion = aggregatedVersion;
        }

        private void setChecksum(String checksum) {
            this.checksum = checksum;
        }

        private void setLastError(String lastError) {
            this.lastError = lastError;
        }

        private void setUpdatedDeviceIds(Set<Long> deviceIds) {
            this.updatedDeviceIds.clear();
            if (deviceIds != null && !deviceIds.isEmpty()) {
                this.updatedDeviceIds.addAll(deviceIds);
            }
        }

        private void markUpdated(long deviceId) {
            updatedDeviceIds.add(deviceId);
        }

        private void markAggregated(Long version, String checksum) {
            this.status = RoundStatus.AGGREGATED;
            this.aggregatedAt = Instant.now();
            this.aggregatedVersion = version;
            this.checksum = checksum;
            this.lastError = null;
        }

        private void markFailed(String error) {
            this.status = RoundStatus.FAILED;
            this.lastError = error;
        }
    }

    private final Map<Long, RoundState> rounds = new ConcurrentHashMap<>();
    private final FlRoundStateRepository flRoundStateRepository;

    public FlRoundTracker(FlRoundStateRepository flRoundStateRepository) {
        this.flRoundStateRepository = flRoundStateRepository;
    }

    @PostConstruct
    public void restoreFromDb() {
        for (FlRoundStateEntity entity : flRoundStateRepository.findAll()) {
            RoundState state = new RoundState(
                    entity.getRoundId(),
                    entity.getCreatedAt(),
                    entity.getDeadlineAt(),
                    entity.getMinClients(),
                    entity.getMinSamples(),
                    parseDeviceIdCsv(entity.getTargetDeviceIds())
            );

            state.setUpdatedDeviceIds(parseDeviceIdCsv(entity.getUpdatedDeviceIds()));
            state.setStatus(parseStatus(entity.getStatus()));
            state.setAggregatedAt(entity.getAggregatedAt());
            state.setAggregatedVersion(entity.getAggregatedVersion());
            state.setChecksum(entity.getChecksum());
            state.setLastError(entity.getLastError());

            rounds.put(state.getRoundId(), state);
        }
    }

    public RoundState createRound(long roundId,
                                  Instant deadlineAt,
                                  int minClients,
                                  int minSamples,
                                  Set<Long> targetDeviceIds) {
        RoundState state = new RoundState(
                roundId,
                Instant.now(),
                deadlineAt,
                minClients,
                minSamples,
                targetDeviceIds
        );
        rounds.put(roundId, state);
            saveState(state);
        return state;
    }

    public boolean exists(long roundId) {
        return rounds.containsKey(roundId);
    }

    public RoundState getRound(long roundId) {
        return rounds.get(roundId);
    }

    public Collection<RoundState> allRounds() {
        return rounds.values();
    }

    public List<RoundState> dueOpenRounds(Instant now) {
        List<RoundState> due = new ArrayList<>();
        for (RoundState round : rounds.values()) {
            if (round.getStatus() == RoundStatus.OPEN && !round.getDeadlineAt().isAfter(now)) {
                due.add(round);
            }
        }
        return due;
    }

    public void markDeviceUpdated(long roundId, long deviceId) {
        RoundState state = rounds.get(roundId);
        if (state != null) {
            state.markUpdated(deviceId);
            saveState(state);
        }
    }

    public void markAggregated(long roundId, Long version, String checksum) {
        RoundState state = rounds.get(roundId);
        if (state != null) {
            state.markAggregated(version, checksum);
            saveState(state);
        }
    }

    public void markFailed(long roundId, String error) {
        RoundState state = rounds.get(roundId);
        if (state != null) {
            state.markFailed(error);
            saveState(state);
        }
    }

    public void deleteRound(long roundId) {
        RoundState state = rounds.remove(roundId);
        if (state != null) {
            flRoundStateRepository.deleteByRoundId(roundId);
        }
    }

    private void saveState(RoundState state) {
        FlRoundStateEntity entity = new FlRoundStateEntity();
        entity.setRoundId(state.getRoundId());
        entity.setCreatedAt(state.getCreatedAt());
        entity.setDeadlineAt(state.getDeadlineAt());
        entity.setMinClients(state.getMinClients());
        entity.setMinSamples(state.getMinSamples());
        entity.setTargetDeviceIds(toDeviceIdCsv(state.getTargetDeviceIds()));
        entity.setUpdatedDeviceIds(toDeviceIdCsv(state.getUpdatedDeviceIds()));
        entity.setStatus(state.getStatus().name());
        entity.setAggregatedAt(state.getAggregatedAt());
        entity.setAggregatedVersion(state.getAggregatedVersion());
        entity.setChecksum(state.getChecksum());
        entity.setLastError(state.getLastError());
        flRoundStateRepository.save(entity);
    }

    private String toDeviceIdCsv(Set<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return "";
        }
        return ids.stream().map(String::valueOf).collect(Collectors.joining(","));
    }

    private Set<Long> parseDeviceIdCsv(String csv) {
        Set<Long> ids = new LinkedHashSet<>();
        if (csv == null || csv.isBlank()) {
            return ids;
        }

        String[] parts = csv.split(",");
        for (String part : parts) {
            String value = part == null ? "" : part.trim();
            if (value.isBlank()) {
                continue;
            }
            try {
                ids.add(Long.parseLong(value));
            } catch (NumberFormatException ignored) {
                // Skip malformed ids to keep startup resilient.
            }
        }
        return ids;
    }

    private RoundStatus parseStatus(String status) {
        if (status == null || status.isBlank()) {
            return RoundStatus.OPEN;
        }
        try {
            return RoundStatus.valueOf(status);
        } catch (IllegalArgumentException ignored) {
            return RoundStatus.OPEN;
        }
    }
}
