package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.FishSpecies;
import backend_iot_aquarium.backend_iot_aquarium.service.FishSpeciesService;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * REST API for managing fish species and their alert thresholds
 * API quản lý các loài cá và ngưỡng cảnh báo
 */
@RestController
@RequestMapping("/api/fish")
@CrossOrigin(origins = "*")
public class FishSpeciesController {

    private final FishSpeciesService fishSpeciesService;

    public FishSpeciesController(FishSpeciesService fishSpeciesService) {
        this.fishSpeciesService = fishSpeciesService;
    }

    /**
     * Get all fish species with complete temperature and pH data
     * GET /api/fish/list
     */
    @GetMapping("/list")
    public ResponseEntity<List<FishSpecies>> getAllFish() {
        List<FishSpecies> fishList = fishSpeciesService.getAllFishWithCompleteData();
        return ResponseEntity.ok(fishList);
    }

    /**
     * Get only fish that already have configured thresholds or recommended ranges.
     * Hỗ trợ phân trang và lọc theo tên (EN/VN).
     * GET /api/fish/configured?page=0&size=50&name=panda
     */
    @GetMapping("/configured")
    public ResponseEntity<Page<FishSpecies>> getConfiguredFish(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(name = "name", required = false) String name) {
        Page<FishSpecies> configured = fishSpeciesService.getConfiguredFishPage(page, size, name);
        return ResponseEntity.ok(configured);
    }

    /**
     * Search fish by name (English or Vietnamese)
     * GET /api/fish/search?name=panda
     * GET /api/fish/search?name=cá
     */
    @GetMapping("/search")
    public ResponseEntity<List<FishSpecies>> searchFish(@RequestParam(required = false) String name) {
        List<FishSpecies> fishList = fishSpeciesService.searchFishByName(name);
        return ResponseEntity.ok(fishList);
    }

    /**
     * Get fish details by ID with effective alert thresholds
     * GET /api/fish/1
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getFishById(@PathVariable Long id) {
        return fishSpeciesService.getFishById(id)
            .map(fish -> {
                Map<String, Object> response = new HashMap<>();
                response.put("fish", fish);
                response.put("effectiveThresholds", Map.of(
                    "tempMin", fishSpeciesService.getEffectiveTempMin(fish),
                    "tempMax", fishSpeciesService.getEffectiveTempMax(fish),
                    "phMin", fishSpeciesService.getEffectivePhMin(fish),
                    "phMax", fishSpeciesService.getEffectivePhMax(fish)
                ));
                response.put("usingCustom", fish.getCustomTempMin() != null || 
                                           fish.getCustomTempMax() != null ||
                                           fish.getCustomPhMin() != null || 
                                           fish.getCustomPhMax() != null);
                return ResponseEntity.ok(response);
            })
            .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Update alert thresholds for a fish species
     * PUT /api/fish/1/thresholds
     * Body: {
     *   "tempMin": 22.0,
     *   "tempMax": 28.0,
     *   "phMin": 6.5,
     *   "phMax": 7.5
     * }
     */
    @PutMapping("/{id}/thresholds")
    public ResponseEntity<Map<String, Object>> updateThresholds(
            @PathVariable Long id,
            @RequestBody Map<String, Double> thresholds) {
        
        try {
            Double tempMin = thresholds.get("tempMin");
            Double tempMax = thresholds.get("tempMax");
            Double phMin = thresholds.get("phMin");
            Double phMax = thresholds.get("phMax");

            FishSpecies updatedFish = fishSpeciesService.updateAlertThresholds(
                id, tempMin, tempMax, phMin, phMax
            );

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Alert thresholds updated successfully");
            response.put("fish", updatedFish);
            response.put("effectiveThresholds", Map.of(
                "tempMin", fishSpeciesService.getEffectiveTempMin(updatedFish),
                "tempMax", fishSpeciesService.getEffectiveTempMax(updatedFish),
                "phMin", fishSpeciesService.getEffectivePhMin(updatedFish),
                "phMax", fishSpeciesService.getEffectivePhMax(updatedFish)
            ));

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("error", e.getMessage());
            return ResponseEntity.badRequest().body(errorResponse);
        }
    }

    /**
     * Reset alert thresholds to default system values
     * POST /api/fish/1/reset
     */
    @PostMapping("/{id}/reset")
    public ResponseEntity<Map<String, Object>> resetThresholds(@PathVariable Long id) {
        try {
            FishSpecies updatedFish = fishSpeciesService.resetAlertThresholds(id);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Alert thresholds reset to default values");
            response.put("fish", updatedFish);
            response.put("defaultThresholds", Map.of(
                "tempMin", fishSpeciesService.getEffectiveTempMin(updatedFish),
                "tempMax", fishSpeciesService.getEffectiveTempMax(updatedFish),
                "phMin", fishSpeciesService.getEffectivePhMin(updatedFish),
                "phMax", fishSpeciesService.getEffectivePhMax(updatedFish)
            ));

            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("error", e.getMessage());
            return ResponseEntity.badRequest().body(errorResponse);
        }
    }

    /**
     * Get default system alert thresholds
     * GET /api/fish/defaults
     */
    @GetMapping("/defaults")
    public ResponseEntity<Map<String, Object>> getDefaultThresholds() {
        FishSpeciesService.AlertThresholds defaults = fishSpeciesService.getDefaultThresholds();
        
        Map<String, Object> response = new HashMap<>();
        response.put("tempMin", defaults.tempMin);
        response.put("tempMax", defaults.tempMax);
        response.put("phMin", defaults.phMin);
        response.put("phMax", defaults.phMax);

        return ResponseEntity.ok(response);
    }

    /**
     * Create a new fish species (minimal fields).
     * POST /api/fish
     */
    @PostMapping
    public ResponseEntity<FishSpecies> createFish(@RequestBody FishSpecies fish) {
        fish.setId(null); // ensure new
        if (fish.getIsActive() == null) {
            fish.setIsActive(true);
        }
        return ResponseEntity.ok(fishSpeciesService.saveFish(fish));
    }
}
