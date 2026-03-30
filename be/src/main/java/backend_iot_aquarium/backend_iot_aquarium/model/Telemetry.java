package backend_iot_aquarium.backend_iot_aquarium.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "telemetry")
public class Telemetry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private LocalDateTime timestamp;

    // Định danh thiết bị/ao (phục vụ mapping sang bảng device/pond sau này)
    private String deviceId;

    private Long pondId;

    private Double temperature;

    private Double waterLevel;

    private Double ph;

    // fields from ESP32 status JSON
    private Boolean floatHigh;
    private Boolean floatLow;
    private Boolean motorRunning;
    private Integer duty;
    private String mode;
    private String direction; // FORWARD, BACKWARD, STOPPED
    private Long uptimeMs;

    @Lob
    private String rawPayload;

    public Telemetry() {}

    @PrePersist
    public void prePersist() {
        if (this.timestamp == null) this.timestamp = LocalDateTime.now();
    }

    // getters / setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }
    public String getDeviceId() { return deviceId; }
    public void setDeviceId(String deviceId) { this.deviceId = deviceId; }
    public Long getPondId() { return pondId; }
    public void setPondId(Long pondId) { this.pondId = pondId; }
    public Double getTemperature() { return temperature; }
    public void setTemperature(Double temperature) { this.temperature = temperature; }
    public Double getWaterLevel() { return waterLevel; }
    public void setWaterLevel(Double waterLevel) { this.waterLevel = waterLevel; }
    public Double getPh() { return ph; }
    public void setPh(Double ph) { this.ph = ph; }
    public Boolean getFloatHigh() { return floatHigh; }
    public void setFloatHigh(Boolean floatHigh) { this.floatHigh = floatHigh; }
    public Boolean getFloatLow() { return floatLow; }
    public void setFloatLow(Boolean floatLow) { this.floatLow = floatLow; }
    public Boolean getMotorRunning() { return motorRunning; }
    public void setMotorRunning(Boolean motorRunning) { this.motorRunning = motorRunning; }
    public Integer getDuty() { return duty; }
    public void setDuty(Integer duty) { this.duty = duty; }
    public String getMode() { return mode; }
    public void setMode(String mode) { this.mode = mode; }
    public String getDirection() { return direction; }
    public void setDirection(String direction) { this.direction = direction; }
    public Long getUptimeMs() { return uptimeMs; }
    public void setUptimeMs(Long uptimeMs) { this.uptimeMs = uptimeMs; }
    public String getRawPayload() { return rawPayload; }
    public void setRawPayload(String rawPayload) { this.rawPayload = rawPayload; }
}
