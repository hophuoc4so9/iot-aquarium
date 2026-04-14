package backend_iot_aquarium.backend_iot_aquarium.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.LocalDateTime;

@Entity
@Table(name = "ponds")
public class Pond {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "area")
    private String area;

    @Column(name = "fish_type")
    private String fishType;

    @Column(name = "stocking_date")
    private String stockingDate;

    @Column(name = "density")
    private String density;

    @Column(name = "note")
    private String note;

    // Username của chủ ao (user app-user). Có thể null nếu ao chưa được gán.
    @Column(name = "owner_username")
    private String ownerUsername;

    // Khóa thiết bị số duy nhất, dùng để map với ESP32 và telemetry.
    @Column(name = "device_id", unique = true)
    private Long deviceId;

    // Snapshot trạng thái telemetry mới nhất của ao
    @Column(name = "last_device_id")
    private Long lastDeviceId;

    @Column(name = "last_temperature")
    private Double lastTemperature;

    @Column(name = "last_ph")
    private Double lastPh;

    @Column(name = "last_water_level")
    private Double lastWaterLevel;

    @Column(name = "last_float_high")
    private Boolean lastFloatHigh;

    @Column(name = "last_float_low")
    private Boolean lastFloatLow;

    @Column(name = "last_motor_running")
    private Boolean lastMotorRunning;

    @Column(name = "last_duty")
    private Integer lastDuty;

    @Column(name = "last_mode")
    private String lastMode;

    @Column(name = "last_direction")
    private String lastDirection;

    @Column(name = "last_uptime_ms")
    private Long lastUptimeMs;

    @Column(name = "last_telemetry_at")
    private LocalDateTime lastTelemetryAt;

    // Ngưỡng riêng theo từng bể (nullable: null = fallback theo loài/hệ thống)
    @Column(name = "custom_temp_min")
    private Double customTempMin;

    @Column(name = "custom_temp_max")
    private Double customTempMax;

    @Column(name = "custom_ph_min")
    private Double customPhMin;

    @Column(name = "custom_ph_max")
    private Double customPhMax;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getArea() {
        return area;
    }

    public void setArea(String area) {
        this.area = area;
    }

    public String getFishType() {
        return fishType;
    }

    public void setFishType(String fishType) {
        this.fishType = fishType;
    }

    public String getStockingDate() {
        return stockingDate;
    }

    public void setStockingDate(String stockingDate) {
        this.stockingDate = stockingDate;
    }

    public String getDensity() {
        return density;
    }

    public void setDensity(String density) {
        this.density = density;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public String getOwnerUsername() {
        return ownerUsername;
    }

    public void setOwnerUsername(String ownerUsername) {
        this.ownerUsername = ownerUsername;
    }

    public Long getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(Long deviceId) {
        this.deviceId = deviceId;
    }

    public Long getLastDeviceId() {
        return lastDeviceId;
    }

    public void setLastDeviceId(Long lastDeviceId) {
        this.lastDeviceId = lastDeviceId;
    }

    public Double getLastTemperature() {
        return lastTemperature;
    }

    public void setLastTemperature(Double lastTemperature) {
        this.lastTemperature = lastTemperature;
    }

    public Double getLastPh() {
        return lastPh;
    }

    public void setLastPh(Double lastPh) {
        this.lastPh = lastPh;
    }

    public Double getLastWaterLevel() {
        return lastWaterLevel;
    }

    public void setLastWaterLevel(Double lastWaterLevel) {
        this.lastWaterLevel = lastWaterLevel;
    }

    public Boolean getLastFloatHigh() {
        return lastFloatHigh;
    }

    public void setLastFloatHigh(Boolean lastFloatHigh) {
        this.lastFloatHigh = lastFloatHigh;
    }

    public Boolean getLastFloatLow() {
        return lastFloatLow;
    }

    public void setLastFloatLow(Boolean lastFloatLow) {
        this.lastFloatLow = lastFloatLow;
    }

    public Boolean getLastMotorRunning() {
        return lastMotorRunning;
    }

    public void setLastMotorRunning(Boolean lastMotorRunning) {
        this.lastMotorRunning = lastMotorRunning;
    }

    public Integer getLastDuty() {
        return lastDuty;
    }

    public void setLastDuty(Integer lastDuty) {
        this.lastDuty = lastDuty;
    }

    public String getLastMode() {
        return lastMode;
    }

    public void setLastMode(String lastMode) {
        this.lastMode = lastMode;
    }

    public String getLastDirection() {
        return lastDirection;
    }

    public void setLastDirection(String lastDirection) {
        this.lastDirection = lastDirection;
    }

    public Long getLastUptimeMs() {
        return lastUptimeMs;
    }

    public void setLastUptimeMs(Long lastUptimeMs) {
        this.lastUptimeMs = lastUptimeMs;
    }

    public LocalDateTime getLastTelemetryAt() {
        return lastTelemetryAt;
    }

    public void setLastTelemetryAt(LocalDateTime lastTelemetryAt) {
        this.lastTelemetryAt = lastTelemetryAt;
    }

    public Double getCustomTempMin() {
        return customTempMin;
    }

    public void setCustomTempMin(Double customTempMin) {
        this.customTempMin = customTempMin;
    }

    public Double getCustomTempMax() {
        return customTempMax;
    }

    public void setCustomTempMax(Double customTempMax) {
        this.customTempMax = customTempMax;
    }

    public Double getCustomPhMin() {
        return customPhMin;
    }

    public void setCustomPhMin(Double customPhMin) {
        this.customPhMin = customPhMin;
    }

    public Double getCustomPhMax() {
        return customPhMax;
    }

    public void setCustomPhMax(Double customPhMax) {
        this.customPhMax = customPhMax;
    }
}

