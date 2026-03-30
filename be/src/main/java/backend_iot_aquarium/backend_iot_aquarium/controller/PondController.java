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
                    existing.setName(payload.getName());
                    existing.setArea(payload.getArea());
                    existing.setFishType(payload.getFishType());
                    existing.setStockingDate(payload.getStockingDate());
                    existing.setDensity(payload.getDensity());
                    existing.setNote(payload.getNote());
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
     * Gán 1 ao cho user hiện tại bằng cách nhập đúng ID ao.
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
        Long pondId = body.get("pondId");
        if (pondId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "pondId is required"));
        }

        String username = userDetails.getUsername();

        return pondRepository.findById(pondId)
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
}

