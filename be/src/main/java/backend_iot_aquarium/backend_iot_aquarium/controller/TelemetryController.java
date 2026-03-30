package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.Telemetry;
import backend_iot_aquarium.backend_iot_aquarium.repository.TelemetryRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST API endpoints for telemetry data
 * Hệ thống giám sát bể cá:
 * - Temperature sensor (DS18B20)
 * - pH sensor (analog probe)
 * - 2 Float switches (HIGH/LOW water level)
 * - Motor control (AUTO/MANUAL mode)
 */
@RestController
@RequestMapping("/api/telemetry")
@CrossOrigin(origins = "*") // Allow web and mobile app to access
public class TelemetryController {

    private final TelemetryRepository repository;

    public TelemetryController(TelemetryRepository repository) {
        this.repository = repository;
    }

    /**
     * Lấy 100 bản ghi telemetry gần nhất
     * GET /api/telemetry/recent
     */
    @GetMapping("/recent")
    public ResponseEntity<List<Telemetry>> recent(@RequestParam(value = "pondId", required = false) Long pondId) {
        if (pondId != null) {
            return ResponseEntity.ok(repository.findTop100ByPondIdOrderByTimestampDesc(pondId));
        }
        return ResponseEntity.ok(repository.findTop100ByOrderByTimestampDesc());
    }

    /**
     * Lấy telemetry theo ID
     * GET /api/telemetry/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<Telemetry> getById(@PathVariable Long id) {
        return repository.findById(id).map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    /**
     * Lấy telemetry mới nhất (dùng cho dashboard)
     * GET /api/telemetry/latest
     */
    @GetMapping("/latest")
    public ResponseEntity<Telemetry> latest(@RequestParam(value = "pondId", required = false) Long pondId) {
        Telemetry t = pondId == null
                ? repository.findTopByOrderByTimestampDesc()
                : repository.findTopByPondIdOrderByTimestampDesc(pondId);
        if (t == null) return ResponseEntity.noContent().build();
        return ResponseEntity.ok(t);
    }
}
