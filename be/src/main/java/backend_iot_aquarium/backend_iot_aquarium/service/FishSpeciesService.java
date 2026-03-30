package backend_iot_aquarium.backend_iot_aquarium.service;

import backend_iot_aquarium.backend_iot_aquarium.model.FishSpecies;
import backend_iot_aquarium.backend_iot_aquarium.repository.FishSpeciesRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
public class FishSpeciesService {

    private final FishSpeciesRepository fishSpeciesRepository;

    @Value("${alerts.temperature.high}")
    private double defaultTempHigh;

    @Value("${alerts.temperature.low}")
    private double defaultTempLow;

    @Value("${alerts.ph.high}")
    private double defaultPhHigh;

    @Value("${alerts.ph.low}")
    private double defaultPhLow;

    public FishSpeciesService(FishSpeciesRepository fishSpeciesRepository) {
        this.fishSpeciesRepository = fishSpeciesRepository;
    }

    /**
     * Get all active fish species (for wiki / admin UI)
     */
    public List<FishSpecies> getAllFishWithCompleteData() {
        return fishSpeciesRepository.findByIsActiveTrueOrderByNameEnglish();
    }

    /**
     * Get only fish that have configured thresholds or recommended ranges, with pagination.
     * Hiện tại: trả về tất cả loài cá active, nhưng có phân trang để không phải load 2000+ bản ghi một lần.
     */
    public Page<FishSpecies> getConfiguredFishPage(int page, int size, String searchTerm) {
        int safePage = Math.max(page, 0);
        int safeSize = size <= 0 ? 50 : Math.min(size, 200);
        Pageable pageable = PageRequest.of(safePage, safeSize);
        // Chỉ lấy các loài đã có dữ liệu temp/pH (tự động hoặc custom) hoặc chuỗi tempRange/phRange,
        // có thể lọc thêm theo tên EN/VN nếu searchTerm không rỗng.
        String term = (searchTerm == null || searchTerm.trim().isEmpty())
                ? null
                : searchTerm.trim();
        return fishSpeciesRepository.findConfiguredFishWithRanges(term, pageable);
    }

    /**
     * Search fish by name (English or Vietnamese) with complete data only
     */
    public List<FishSpecies> searchFishByName(String searchTerm) {
        if (searchTerm == null || searchTerm.trim().isEmpty()) {
            return getAllFishWithCompleteData();
        }
        return fishSpeciesRepository.searchByNameWithCompleteData(searchTerm.trim());
    }

    /**
     * Get fish by ID
     */
    public Optional<FishSpecies> getFishById(Long id) {
        return fishSpeciesRepository.findById(id);
    }

    /**
     * Update custom alert thresholds for a fish species
     */
    @Transactional
    public FishSpecies updateAlertThresholds(Long fishId, Double tempMin, Double tempMax, 
                                            Double phMin, Double phMax) {
        FishSpecies fish = fishSpeciesRepository.findById(fishId)
            .orElseThrow(() -> new RuntimeException("Fish species not found with id: " + fishId));

        fish.setCustomTempMin(tempMin);
        fish.setCustomTempMax(tempMax);
        fish.setCustomPhMin(phMin);
        fish.setCustomPhMax(phMax);

        return fishSpeciesRepository.save(fish);
    }

    /**
     * Reset alert thresholds to default (system values)
     */
    @Transactional
    public FishSpecies resetAlertThresholds(Long fishId) {
        FishSpecies fish = fishSpeciesRepository.findById(fishId)
            .orElseThrow(() -> new RuntimeException("Fish species not found with id: " + fishId));

        fish.setCustomTempMin(null);
        fish.setCustomTempMax(null);
        fish.setCustomPhMin(null);
        fish.setCustomPhMax(null);

        return fishSpeciesRepository.save(fish);
    }

    /**
     * Get effective temperature min for a fish.
     * Ưu tiên: customTempMin -> autoTempMin (từ dataset, ví dụ freshwater_aquarium_fish_species.csv) -> defaultTempLow.
     */
    public double getEffectiveTempMin(FishSpecies fish) {
        if (fish.getCustomTempMin() != null) {
            return fish.getCustomTempMin();
        }
        if (fish.getAutoTempMin() != null) {
            return fish.getAutoTempMin();
        }
        return defaultTempLow;
    }

    /**
     * Get effective temperature max for a fish.
     * Ưu tiên: customTempMax -> autoTempMax -> defaultTempHigh.
     */
    public double getEffectiveTempMax(FishSpecies fish) {
        if (fish.getCustomTempMax() != null) {
            return fish.getCustomTempMax();
        }
        if (fish.getAutoTempMax() != null) {
            return fish.getAutoTempMax();
        }
        return defaultTempHigh;
    }

    /**
     * Get effective pH min for a fish.
     * Ưu tiên: customPhMin -> autoPhMin -> defaultPhLow.
     */
    public double getEffectivePhMin(FishSpecies fish) {
        if (fish.getCustomPhMin() != null) {
            return fish.getCustomPhMin();
        }
        if (fish.getAutoPhMin() != null) {
            return fish.getAutoPhMin();
        }
        return defaultPhLow;
    }

    /**
     * Get effective pH max for a fish.
     * Ưu tiên: customPhMax -> autoPhMax -> defaultPhHigh.
     */
    public double getEffectivePhMax(FishSpecies fish) {
        if (fish.getCustomPhMax() != null) {
            return fish.getCustomPhMax();
        }
        if (fish.getAutoPhMax() != null) {
            return fish.getAutoPhMax();
        }
        return defaultPhHigh;
    }

    /**
     * Get default alert thresholds
     */
    public AlertThresholds getDefaultThresholds() {
        return new AlertThresholds(defaultTempLow, defaultTempHigh, defaultPhLow, defaultPhHigh);
    }

    /**
     * Save a fish species (used for creating new species from admin UI).
     */
    @Transactional
    public FishSpecies saveFish(FishSpecies fish) {
        return fishSpeciesRepository.save(fish);
    }

    /**
     * Simple class to hold threshold values
     */
    public static class AlertThresholds {
        public final double tempMin;
        public final double tempMax;
        public final double phMin;
        public final double phMax;

        public AlertThresholds(double tempMin, double tempMax, double phMin, double phMax) {
            this.tempMin = tempMin;
            this.tempMax = tempMax;
            this.phMin = phMin;
            this.phMax = phMax;
        }
    }
}
