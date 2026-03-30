package backend_iot_aquarium.backend_iot_aquarium.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * Entity representing fish species with custom alert thresholds
 * Thông tin loài cá với ngưỡng cảnh báo tùy chỉnh
 */
@Entity
@Table(name = "fish_species")
public class FishSpecies {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "spec_code", unique = true)
    private Integer specCode;

    @Column(name = "name_english", nullable = false)
    private String nameEnglish;

    @Column(name = "name_vietnamese")
    private String nameVietnamese;

    @Column(name = "fb_name")
    private String fbName;

    @Column(name = "name_key", length = 255)
    private String nameKey;

    @Column(name = "taxonomy")
    private String taxonomy;

    @Column(name = "pic_preferred_name")
    private String picPreferredName;

    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    @Column(name = "remarks", columnDefinition = "TEXT")
    private String remarks;

    @Column(name = "remarks_en", columnDefinition = "TEXT")
    private String remarksEn;

    @Column(name = "remarks_vi", columnDefinition = "TEXT")
    private String remarksVi;

    @Column(name = "fishbase_species_info_json", columnDefinition = "LONGTEXT")
    private String fishbaseSpeciesInfoJson;

    @Column(name = "fishbase_ecology_json", columnDefinition = "LONGTEXT")
    private String fishbaseEcologyJson;

    // Vietnam-specific distribution info from vn_fish_species_list.csv
    @Column(name = "vn_status")
    private String vnStatus;

    @Column(name = "vn_current_presence")
    private String vnCurrentPresence;

    @Column(name = "vn_freshwater_flag")
    private Boolean vnFreshwater;

    @Column(name = "vn_brackish_flag")
    private Boolean vnBrackish;

    @Column(name = "vn_saltwater_flag")
    private Boolean vnSaltwater;

    @Column(name = "vn_distribution_comments", columnDefinition = "TEXT")
    private String vnDistributionComments;

    @Column(name = "vn_abundance")
    private String vnAbundance;

    @Column(name = "vn_importance")
    private String vnImportance;

    @Column(name = "temp_range", length = 100)
    private String tempRange;

    @Column(name = "ph_range", length = 50)
    private String phRange;

    @Column(name = "details_url", columnDefinition = "TEXT")
    private String detailsUrl;

    // Auto ranges (suggested from dataset, not directly editable by user)
    @Column(name = "auto_temp_min")
    private Double autoTempMin;

    @Column(name = "auto_temp_max")
    private Double autoTempMax;

    @Column(name = "auto_ph_min")
    private Double autoPhMin;

    @Column(name = "auto_ph_max")
    private Double autoPhMax;

    // Custom alert thresholds (nullable - if null, use system defaults)
    @Column(name = "custom_temp_min")
    private Double customTempMin;

    @Column(name = "custom_temp_max")
    private Double customTempMax;

    @Column(name = "custom_ph_min")
    private Double customPhMin;

    @Column(name = "custom_ph_max")
    private Double customPhMax;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // Constructors
    public FishSpecies() {
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Integer getSpecCode() {
        return specCode;
    }

    public void setSpecCode(Integer specCode) {
        this.specCode = specCode;
    }

    public String getNameEnglish() {
        return nameEnglish;
    }

    public void setNameEnglish(String nameEnglish) {
        this.nameEnglish = nameEnglish;
    }

    public String getNameVietnamese() {
        return nameVietnamese;
    }

    public void setNameVietnamese(String nameVietnamese) {
        this.nameVietnamese = nameVietnamese;
    }

    public String getFbName() {
        return fbName;
    }

    public void setFbName(String fbName) {
        this.fbName = fbName;
    }

    public String getNameKey() {
        return nameKey;
    }

    public void setNameKey(String nameKey) {
        this.nameKey = nameKey;
    }

    public String getTaxonomy() {
        return taxonomy;
    }

    public void setTaxonomy(String taxonomy) {
        this.taxonomy = taxonomy;
    }

    public String getPicPreferredName() {
        return picPreferredName;
    }

    public void setPicPreferredName(String picPreferredName) {
        this.picPreferredName = picPreferredName;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }

    public String getRemarks() {
        return remarks;
    }

    public void setRemarks(String remarks) {
        this.remarks = remarks;
    }

    public String getRemarksEn() {
        return remarksEn;
    }

    public void setRemarksEn(String remarksEn) {
        this.remarksEn = remarksEn;
    }

    public String getRemarksVi() {
        return remarksVi;
    }

    public void setRemarksVi(String remarksVi) {
        this.remarksVi = remarksVi;
    }

    public String getFishbaseSpeciesInfoJson() {
        return fishbaseSpeciesInfoJson;
    }

    public void setFishbaseSpeciesInfoJson(String fishbaseSpeciesInfoJson) {
        this.fishbaseSpeciesInfoJson = fishbaseSpeciesInfoJson;
    }

    public String getFishbaseEcologyJson() {
        return fishbaseEcologyJson;
    }

    public void setFishbaseEcologyJson(String fishbaseEcologyJson) {
        this.fishbaseEcologyJson = fishbaseEcologyJson;
    }

    public String getVnStatus() {
        return vnStatus;
    }

    public void setVnStatus(String vnStatus) {
        this.vnStatus = vnStatus;
    }

    public String getVnCurrentPresence() {
        return vnCurrentPresence;
    }

    public void setVnCurrentPresence(String vnCurrentPresence) {
        this.vnCurrentPresence = vnCurrentPresence;
    }

    public Boolean getVnFreshwater() {
        return vnFreshwater;
    }

    public void setVnFreshwater(Boolean vnFreshwater) {
        this.vnFreshwater = vnFreshwater;
    }

    public Boolean getVnBrackish() {
        return vnBrackish;
    }

    public void setVnBrackish(Boolean vnBrackish) {
        this.vnBrackish = vnBrackish;
    }

    public Boolean getVnSaltwater() {
        return vnSaltwater;
    }

    public void setVnSaltwater(Boolean vnSaltwater) {
        this.vnSaltwater = vnSaltwater;
    }

    public String getVnDistributionComments() {
        return vnDistributionComments;
    }

    public void setVnDistributionComments(String vnDistributionComments) {
        this.vnDistributionComments = vnDistributionComments;
    }

    public String getVnAbundance() {
        return vnAbundance;
    }

    public void setVnAbundance(String vnAbundance) {
        this.vnAbundance = vnAbundance;
    }

    public String getVnImportance() {
        return vnImportance;
    }

    public void setVnImportance(String vnImportance) {
        this.vnImportance = vnImportance;
    }

    public String getTempRange() {
        return tempRange;
    }

    public void setTempRange(String tempRange) {
        this.tempRange = tempRange;
    }

    public String getPhRange() {
        return phRange;
    }

    public void setPhRange(String phRange) {
        this.phRange = phRange;
    }

    public String getDetailsUrl() {
        return detailsUrl;
    }

    public void setDetailsUrl(String detailsUrl) {
        this.detailsUrl = detailsUrl;
    }

    public Double getAutoTempMin() {
        return autoTempMin;
    }

    public void setAutoTempMin(Double autoTempMin) {
        this.autoTempMin = autoTempMin;
    }

    public Double getAutoTempMax() {
        return autoTempMax;
    }

    public void setAutoTempMax(Double autoTempMax) {
        this.autoTempMax = autoTempMax;
    }

    public Double getAutoPhMin() {
        return autoPhMin;
    }

    public void setAutoPhMin(Double autoPhMin) {
        this.autoPhMin = autoPhMin;
    }

    public Double getAutoPhMax() {
        return autoPhMax;
    }

    public void setAutoPhMax(Double autoPhMax) {
        this.autoPhMax = autoPhMax;
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

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
