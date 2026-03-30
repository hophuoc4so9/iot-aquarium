package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.FishSpecies;
import backend_iot_aquarium.backend_iot_aquarium.repository.FishSpeciesRepository;
import backend_iot_aquarium.backend_iot_aquarium.service.FishSpeciesImportService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.util.Map;

/**
 * Admin endpoints for managing fish species dataset import.
 */
@RestController
@RequestMapping("/api/admin/fish")
@CrossOrigin(origins = "*")
public class FishAdminController {

    private final FishSpeciesImportService importService;
    private final FishSpeciesRepository fishSpeciesRepository;

    public FishAdminController(FishSpeciesImportService importService,
                               FishSpeciesRepository fishSpeciesRepository) {
        this.importService = importService;
        this.fishSpeciesRepository = fishSpeciesRepository;
    }

    /**
     * Import or update fish species info from CSV into the database.
     * POST /api/admin/fish/import
     */
    @PostMapping("/import")
    public ResponseEntity<Map<String, Object>> importFish() {
        try {
            importService.importAllFromCsv();
            return ResponseEntity.ok(
                    Map.of(
                            "success", true,
                            "message", "Imported fish species (info EN, info VI, ecology VI) from CSV successfully"
                    )
            );
        } catch (IOException e) {
            return ResponseEntity.badRequest().body(
                    Map.of(
                            "success", false,
                            "error", "IO error: " + e.getMessage()
                    )
            );
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(
                    Map.of(
                            "success", false,
                            "error", e.getMessage()
                    )
            );
        }
    }

    /**
     * Cập nhật thông tin wiki cho một loài cá (tên EN/VN, mô tả EN/VN, ngưỡng mô tả).
     * PUT /api/admin/fish/{id}/wiki
     */
    @PutMapping("/{id}/wiki")
    public ResponseEntity<Map<String, Object>> updateWiki(
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {

        return fishSpeciesRepository.findById(id)
                .map(fish -> {
                    String nameEn = (String) body.getOrDefault("nameEnglish", fish.getNameEnglish());
                    String nameVi = (String) body.getOrDefault("nameVietnamese", fish.getNameVietnamese());
                    String remarksEn = (String) body.getOrDefault("remarksEn", fish.getRemarksEn());
                    String remarksVi = (String) body.getOrDefault("remarksVi", fish.getRemarksVi());
                    String tempRange = (String) body.getOrDefault("tempRange", fish.getTempRange());
                    String phRange = (String) body.getOrDefault("phRange", fish.getPhRange());
                    String imageUrl = (String) body.getOrDefault("imageUrl", fish.getImageUrl());
                    String taxonomy = (String) body.getOrDefault("taxonomy", fish.getTaxonomy());

                    fish.setNameEnglish(nameEn);
                    fish.setNameVietnamese(nameVi);
                    fish.setRemarksEn(remarksEn);
                    fish.setRemarksVi(remarksVi);
                    // remarks mặc định hiển thị ưu tiên tiếng Việt, fallback EN
                    if (remarksVi != null && !remarksVi.isBlank()) {
                        fish.setRemarks(remarksVi);
                    } else {
                        fish.setRemarks(remarksEn);
                    }
                    fish.setTempRange(tempRange);
                    fish.setPhRange(phRange);
                    fish.setImageUrl(imageUrl);
                    fish.setTaxonomy(taxonomy);

                    FishSpecies saved = fishSpeciesRepository.save(fish);

                    return ResponseEntity.ok(
                            Map.of(
                                    "success", true,
                                    "fish", saved
                            )
                    );
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }
}

