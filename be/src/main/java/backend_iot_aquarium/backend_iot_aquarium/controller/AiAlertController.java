package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.service.AlertService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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

    public AiAlertController(AlertService alertService) {
        this.alertService = alertService;
    }

    @GetMapping("/ponds/{pondId}/alerts")
    public Map<String, Object> getAlertsForPond(@PathVariable Long pondId) {
        // Hiện tại chưa truyền pondThresholds / fishThresholds -> để AI fallback về mặc định.
        return alertService.getAiAlertsForPond(pondId, null, null);
    }
}

