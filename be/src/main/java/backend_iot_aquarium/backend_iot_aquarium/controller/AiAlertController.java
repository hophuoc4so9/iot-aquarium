package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.repository.PondRepository;
import backend_iot_aquarium.backend_iot_aquarium.service.AlertService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

/**
 * API cho web-admin / app-user lấy cảnh báo AI theo ao.
 *
 * AI service sẽ tự quyết định ngưỡng (theo ao / loài cá / mặc định),
 * nên ở đây tạm thời không nhận body ngưỡng từ client.
 * Nếu sau này cần ngưỡng tuỳ biến theo user, có thể mở rộng sang POST với body.
 */
@RestController
@RequestMapping("/api/ai")
public class AiAlertController {

    private final AlertService alertService;
    private final PondRepository pondRepository;

    public AiAlertController(AlertService alertService, PondRepository pondRepository) {
        this.alertService = alertService;
        this.pondRepository = pondRepository;
    }

    @GetMapping("/ponds/{pondId}/alerts")
    public ResponseEntity<Map<String, Object>> getAlertsForPond(@PathVariable Long pondId) {
        Long targetPondId = pondRepository.findById(pondId)
                .map(p -> p.getDeviceId() != null ? p.getDeviceId() : p.getId())
                .orElse(pondId);
        // Hiện tại chưa truyền pondThresholds / fishThresholds -> để AI fallback về mặc định.
        try {
            return ResponseEntity.ok(alertService.getAiAlertsForPond(targetPondId, null, null));
        } catch (ResponseStatusException ex) {
            // Không làm vỡ dashboard nếu AI service chưa có dữ liệu ao/telemetry.
            return ResponseEntity.ok(Map.of(
                    "pondId", targetPondId,
                    "thresholdsSource", "SYSTEM_DEFAULT",
                    "alerts", List.of(),
                    "warning", "AI alerts fallback",
                    "fallback", true
            ));
        }
    }
}

