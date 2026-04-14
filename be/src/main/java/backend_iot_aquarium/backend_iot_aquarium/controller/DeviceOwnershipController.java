package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.DeviceOwnership;
import backend_iot_aquarium.backend_iot_aquarium.repository.DeviceOwnershipRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/ponds/device-ownership")
@CrossOrigin(origins = "*")
public class DeviceOwnershipController {

    private final DeviceOwnershipRepository repository;

    public DeviceOwnershipController(DeviceOwnershipRepository repository) {
        this.repository = repository;
    }

    @PostMapping("/claim")
    public ResponseEntity<?> claimDevice(@RequestBody Map<String, Long> body,
                                         @AuthenticationPrincipal UserDetails userDetails) {
        Long deviceId = body.get("deviceId");
        if (deviceId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "deviceId is required"));
        }

        String username = userDetails.getUsername();

        return repository.findByDeviceId(deviceId)
                .map(existing -> {
                    if (!existing.getOwnerUsername().equals(username)) {
                        return ResponseEntity.status(403)
                                .body(Map.of("error", "Device is already claimed by another user"));
                    }
                    return ResponseEntity.ok(existing);
                })
                .orElseGet(() -> {
                    DeviceOwnership ownership = new DeviceOwnership();
                    ownership.setDeviceId(deviceId);
                    ownership.setOwnerUsername(username);
                    DeviceOwnership saved = repository.save(ownership);
                    return ResponseEntity.ok(saved);
                });
    }

    @GetMapping("/my")
    public ResponseEntity<List<DeviceOwnership>> myDevices(@AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(repository.findByOwnerUsername(userDetails.getUsername()));
    }
}
