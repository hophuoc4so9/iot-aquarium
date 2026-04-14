package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.Pond;
import backend_iot_aquarium.backend_iot_aquarium.repository.PondRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/ponds")
@CrossOrigin(origins = "*")
public class PondController {

    private final PondRepository pondRepository;

    public PondController(PondRepository pondRepository) {
        this.pondRepository = pondRepository;
    }

    @GetMapping
    public ResponseEntity<Page<Pond>> getAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.max(size, 1));
        Page<Pond> result = pondRepository.findAll(pageable);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/snapshots")
    public ResponseEntity<Page<PondSnapshotResponse>> getSnapshots(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.max(size, 1));
        Page<PondSnapshotResponse> result = pondRepository.findAll(pageable).map(this::toSnapshot);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/my/snapshots")
    public ResponseEntity<List<PondSnapshotResponse>> getMySnapshots(@AuthenticationPrincipal UserDetails userDetails) {
        String username = userDetails.getUsername();
        List<PondSnapshotResponse> snapshots = pondRepository.findByOwnerUsername(username)
                .stream()
                .map(this::toSnapshot)
                .toList();
        return ResponseEntity.ok(snapshots);
    }

    @PostMapping
    public ResponseEntity<Pond> create(@RequestBody Pond pond) {
        pond.setId(null);
        Pond saved = pondRepository.save(pond);
        return ResponseEntity.ok(saved);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Pond> update(@PathVariable Long id, @RequestBody Pond payload) {
        return pondRepository.findById(id)
                .map(existing -> {
                    if (payload.getName() != null) {
                        existing.setName(payload.getName());
                    }
                    if (payload.getArea() != null) {
                        existing.setArea(payload.getArea());
                    }
                    if (payload.getFishType() != null) {
                        existing.setFishType(payload.getFishType());
                    }
                    if (payload.getStockingDate() != null) {
                        existing.setStockingDate(payload.getStockingDate());
                    }
                    if (payload.getDensity() != null) {
                        existing.setDensity(payload.getDensity());
                    }
                    if (payload.getNote() != null) {
                        existing.setNote(payload.getNote());
                    }
                    if (payload.getCustomTempMin() != null) {
                        existing.setCustomTempMin(payload.getCustomTempMin());
                    }
                    if (payload.getCustomTempMax() != null) {
                        existing.setCustomTempMax(payload.getCustomTempMax());
                    }
                    if (payload.getCustomPhMin() != null) {
                        existing.setCustomPhMin(payload.getCustomPhMin());
                    }
                    if (payload.getCustomPhMax() != null) {
                        existing.setCustomPhMax(payload.getCustomPhMax());
                    }
                    Pond saved = pondRepository.save(existing);
                    return ResponseEntity.ok(saved);
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/thresholds")
    public ResponseEntity<?> updateThresholds(@PathVariable Long id, @RequestBody Map<String, Double> body) {
        Double tempMin = body.get("tempMin");
        Double tempMax = body.get("tempMax");
        Double phMin = body.get("phMin");
        Double phMax = body.get("phMax");

        if (tempMin == null || tempMax == null || phMin == null || phMax == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "tempMin,tempMax,phMin,phMax are required"));
        }

        return pondRepository.findById(id)
                .map(existing -> {
                    existing.setCustomTempMin(tempMin);
                    existing.setCustomTempMax(tempMax);
                    existing.setCustomPhMin(phMin);
                    existing.setCustomPhMax(phMax);
                    Pond saved = pondRepository.save(existing);
                    return ResponseEntity.ok(saved);
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/thresholds/reset")
    public ResponseEntity<?> resetThresholds(@PathVariable Long id) {
        return pondRepository.findById(id)
                .map(existing -> {
                    existing.setCustomTempMin(null);
                    existing.setCustomTempMax(null);
                    existing.setCustomPhMin(null);
                    existing.setCustomPhMax(null);
                    Pond saved = pondRepository.save(existing);
                    return ResponseEntity.ok(saved);
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if (!pondRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        pondRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    /**
     * Trả về danh sách ao thuộc về user hiện tại (theo ownerUsername).
     * GET /api/ponds/my
     */
    @GetMapping("/my")
    public ResponseEntity<List<Pond>> getMyPonds(@AuthenticationPrincipal UserDetails userDetails) {
        String username = userDetails.getUsername();
        List<Pond> ponds = pondRepository.findByOwnerUsername(username);
        return ResponseEntity.ok(ponds);
    }

    /**
        * Gán 1 ao cho user hiện tại bằng cách nhập đúng ID ao nội bộ
        * hoặc MQTT pond ID từ ESP32.
     * Logic:
     * - Nếu không tồn tại ao -> 404.
     * - Nếu ao đã có owner khác -> 403.
     * - Nếu ao chưa có owner hoặc đã thuộc về user hiện tại -> gán ownerUsername = currentUser.
     *
        * Body: { "pondId": 123 }
     */
    @PostMapping("/bind-by-id")
    public ResponseEntity<?> bindPondById(@RequestBody Map<String, Long> body,
                                          @AuthenticationPrincipal UserDetails userDetails) {
        Long searchId = body.get("deviceId");
        if (searchId == null) {
            searchId = body.get("pondId");
        }
        if (searchId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "deviceId is required"));
        }

        String username = userDetails.getUsername();
        Long finalSearchId = searchId;

        return pondRepository.findById(finalSearchId)
            .or(() -> pondRepository.findByDeviceId(finalSearchId))
                .map(pond -> {
                    String owner = pond.getOwnerUsername();
                    if (owner != null && !owner.equals(username)) {
                        return ResponseEntity.status(403).body(
                                Map.of("error", "Pond is already assigned to another user")
                        );
                    }

                    pond.setOwnerUsername(username);
                    Pond saved = pondRepository.save(pond);
                    return ResponseEntity.ok(saved);
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    private PondSnapshotResponse toSnapshot(Pond pond) {
        return new PondSnapshotResponse(
                pond.getId(),
                pond.getDeviceId(),
                pond.getName(),
                pond.getOwnerUsername(),
                pond.getLastDeviceId(),
                pond.getLastTemperature(),
                pond.getLastPh(),
                pond.getLastWaterLevel(),
                pond.getLastFloatHigh(),
                pond.getLastFloatLow(),
                pond.getLastMotorRunning(),
                pond.getLastDuty(),
                pond.getLastMode(),
                pond.getLastDirection(),
                pond.getLastUptimeMs(),
                pond.getLastTelemetryAt(),
                pond.getCustomTempMin(),
                pond.getCustomTempMax(),
                pond.getCustomPhMin(),
                pond.getCustomPhMax()
        );
    }

    public record PondSnapshotResponse(
            Long id,
            Long deviceId,
            String name,
            String ownerUsername,
            Long lastDeviceId,
            Double lastTemperature,
            Double lastPh,
            Double lastWaterLevel,
            Boolean lastFloatHigh,
            Boolean lastFloatLow,
            Boolean lastMotorRunning,
            Integer lastDuty,
            String lastMode,
            String lastDirection,
            Long lastUptimeMs,
            LocalDateTime lastTelemetryAt,
            Double customTempMin,
            Double customTempMax,
            Double customPhMin,
            Double customPhMax
    ) {
    }
}

