package backend_iot_aquarium.backend_iot_aquarium.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "fl_round_states")
public class FlRoundStateEntity {

    @Id
    @Column(name = "round_id", nullable = false)
    private Long roundId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "deadline_at", nullable = false)
    private Instant deadlineAt;

    @Column(name = "min_clients", nullable = false)
    private Integer minClients;

    @Column(name = "min_samples", nullable = false)
    private Integer minSamples;

    @Column(name = "target_device_ids", length = 4000)
    private String targetDeviceIds;

    @Column(name = "updated_device_ids", length = 4000)
    private String updatedDeviceIds;

    @Column(name = "status", nullable = false, length = 32)
    private String status;

    @Column(name = "aggregated_at")
    private Instant aggregatedAt;

    @Column(name = "aggregated_version")
    private Long aggregatedVersion;

    @Column(name = "checksum", length = 255)
    private String checksum;

    @Column(name = "last_error", length = 1000)
    private String lastError;

    public Long getRoundId() {
        return roundId;
    }

    public void setRoundId(Long roundId) {
        this.roundId = roundId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getDeadlineAt() {
        return deadlineAt;
    }

    public void setDeadlineAt(Instant deadlineAt) {
        this.deadlineAt = deadlineAt;
    }

    public Integer getMinClients() {
        return minClients;
    }

    public void setMinClients(Integer minClients) {
        this.minClients = minClients;
    }

    public Integer getMinSamples() {
        return minSamples;
    }

    public void setMinSamples(Integer minSamples) {
        this.minSamples = minSamples;
    }

    public String getTargetDeviceIds() {
        return targetDeviceIds;
    }

    public void setTargetDeviceIds(String targetDeviceIds) {
        this.targetDeviceIds = targetDeviceIds;
    }

    public String getUpdatedDeviceIds() {
        return updatedDeviceIds;
    }

    public void setUpdatedDeviceIds(String updatedDeviceIds) {
        this.updatedDeviceIds = updatedDeviceIds;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getAggregatedAt() {
        return aggregatedAt;
    }

    public void setAggregatedAt(Instant aggregatedAt) {
        this.aggregatedAt = aggregatedAt;
    }

    public Long getAggregatedVersion() {
        return aggregatedVersion;
    }

    public void setAggregatedVersion(Long aggregatedVersion) {
        this.aggregatedVersion = aggregatedVersion;
    }

    public String getChecksum() {
        return checksum;
    }

    public void setChecksum(String checksum) {
        this.checksum = checksum;
    }

    public String getLastError() {
        return lastError;
    }

    public void setLastError(String lastError) {
        this.lastError = lastError;
    }
}