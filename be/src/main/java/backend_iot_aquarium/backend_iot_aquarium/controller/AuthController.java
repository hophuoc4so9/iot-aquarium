package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.UserAccount;
import backend_iot_aquarium.backend_iot_aquarium.service.UserAccountService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private final UserAccountService userAccountService;

    public AuthController(UserAccountService userAccountService) {
        this.userAccountService = userAccountService;
    }

    /**
     * Đăng ký user mới (role USER).
     * Body: { "username": "...", "password": "...", "fullName": "..." }
     */
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, String> body) {
        String username = body.get("username");
        String password = body.get("password");
        String fullName = body.getOrDefault("fullName", "");

        if (username == null || username.isBlank() || password == null || password.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "username and password are required"));
        }

        if (userAccountService.usernameExists(username)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Username already exists"));
        }

        UserAccount user = userAccountService.registerUser(username, password, fullName);
        return ResponseEntity.ok(Map.of(
                "id", user.getId(),
                "username", user.getUsername(),
                "fullName", user.getFullName(),
                "role", user.getRole()
        ));
    }

    /**
     * Đăng ký admin mới (role ADMIN) - chỉ dùng cho môi trường dev.
     * Body: { "username": "...", "password": "...", "fullName": "...", "secret": "dev-secret" }
     */
    @PostMapping("/register-admin")
    public ResponseEntity<?> registerAdmin(@RequestBody Map<String, String> body) {
        String username = body.get("username");
        String password = body.get("password");
        String fullName = body.getOrDefault("fullName", "Admin");
        String secret = body.get("secret");

        if (username == null || username.isBlank() || password == null || password.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "username and password are required"));
        }

        // Đơn giản: check chuỗi secret cứng để tránh lộ admin khi public
        if (!"dev-secret".equals(secret)) {
            return ResponseEntity.status(403).body(Map.of("error", "Invalid admin secret"));
        }

        if (userAccountService.usernameExists(username)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Username already exists"));
        }

        UserAccount admin = userAccountService.registerAdmin(username, password, fullName);
        return ResponseEntity.ok(Map.of(
                "id", admin.getId(),
                "username", admin.getUsername(),
                "fullName", admin.getFullName(),
                "role", admin.getRole()
        ));
    }

    /**
     * Trả về thông tin user hiện tại (dùng HTTP Basic).
     * GET /api/auth/me
     */
    @GetMapping("/me")
    public ResponseEntity<?> me(@AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Not authenticated"));
        }
        String username = userDetails.getUsername();
        return userAccountService.findByUsername(username)
                .map(user -> ResponseEntity.ok(Map.of(
                        "id", user.getId(),
                        "username", user.getUsername(),
                        "fullName", user.getFullName(),
                        "role", user.getRole()
                )))
                .orElseGet(() -> ResponseEntity.status(404).body(Map.of("error", "User not found")));
    }
}

