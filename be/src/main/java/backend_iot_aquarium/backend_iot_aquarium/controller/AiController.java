package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.FishDiseaseDiagnosis;
import backend_iot_aquarium.backend_iot_aquarium.model.Pond;
import backend_iot_aquarium.backend_iot_aquarium.repository.FishDiseaseDiagnosisRepository;
import backend_iot_aquarium.backend_iot_aquarium.repository.PondRepository;
import backend_iot_aquarium.backend_iot_aquarium.service.AiGatewayService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * REST API proxy sang AI service (Python).
 * - /api/ai/forecast
 * - /api/ai/fish-disease
 */
@RestController
@RequestMapping("/api/ai")
@CrossOrigin(origins = "*")
public class AiController {

    private final AiGatewayService aiGatewayService;
    private final PondRepository pondRepository;
    private final FishDiseaseDiagnosisRepository diagnosisRepository;

    public AiController(AiGatewayService aiGatewayService,
                        PondRepository pondRepository,
                        FishDiseaseDiagnosisRepository diagnosisRepository) {
        this.aiGatewayService = aiGatewayService;
        this.pondRepository = pondRepository;
        this.diagnosisRepository = diagnosisRepository;
    }

    @PostMapping("/forecast")
    public ResponseEntity<Map<String, Object>> forecast(
            @RequestParam("pondId") Long pondId,
            @RequestParam("metric") String metric,
            @RequestParam(value = "horizonHours", defaultValue = "6") int horizonHours
    ) {
        Long targetPondId = pondRepository.findById(pondId)
            .map(p -> p.getDeviceId() != null ? p.getDeviceId() : p.getId())
            .orElse(pondId);
        Map<String, Object> result = aiGatewayService.forecast(targetPondId, metric, horizonHours);
        return ResponseEntity.ok(result);
    }

    @PostMapping("/fish-disease")
    public ResponseEntity<Map<String, Object>> fishDisease(
            @RequestParam(value = "pondId", required = false) Long pondId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam("file") MultipartFile file
    ) {
        String username = userDetails != null ? userDetails.getUsername() : null;
        Pond pond = null;
        Long targetPondId = pondId;

        if (pondId != null) {
            if (username == null) {
                return ResponseEntity.status(401).body(Map.of("error", "Authentication is required when pondId is provided"));
            }
            Optional<Pond> pondOpt = pondRepository.findById(pondId)
                    .or(() -> pondRepository.findByDeviceId(pondId));
            if (pondOpt.isEmpty()) {
                return ResponseEntity.status(404).body(Map.of("error", "Pond not found"));
            }
            pond = pondOpt.get();
            if (pond.getOwnerUsername() == null || !pond.getOwnerUsername().equals(username)) {
                return ResponseEntity.status(403).body(Map.of("error", "You do not have access to this pond"));
            }
            targetPondId = pond.getDeviceId() != null ? pond.getDeviceId() : pond.getId();
        }

        Map<String, Object> result = aiGatewayService.classifyFishDisease(targetPondId, file);

        if (username != null) {
            FishDiseaseDiagnosis diagnosis = new FishDiseaseDiagnosis();
            diagnosis.setUsername(username);
            diagnosis.setPondId(pond != null ? pond.getId() : null);
            diagnosis.setPondName(pond != null ? pond.getName() : null);
            diagnosis.setImageName(file.getOriginalFilename());
            diagnosis.setLabel(String.valueOf(result.getOrDefault("label", "unknown")));
            Object scoreObj = result.get("score");
            if (scoreObj instanceof Number number) {
                diagnosis.setScore(number.doubleValue());
            }
            diagnosis.setDiagnosedAt(Instant.now());
            diagnosisRepository.save(diagnosis);
        }

        return ResponseEntity.ok(result);
    }

    @ExceptionHandler({MissingServletRequestPartException.class, MissingServletRequestParameterException.class})
    public ResponseEntity<Map<String, Object>> handleMissingMultipartPart(Exception ex) {
        return ResponseEntity.badRequest().body(Map.of(
                "error", "Invalid request",
                "message", "Use POST multipart/form-data with field 'file'. pondId is optional."
        ));
    }

    @GetMapping("/fish-disease/history")
    public ResponseEntity<?> fishDiseaseHistory(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(value = "pondId", required = false) Long pondId
    ) {
        if (userDetails == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Not authenticated"));
        }

        String username = userDetails.getUsername();
        Long normalizedPondId = null;
        if (pondId != null) {
            Optional<Pond> pondOpt = pondRepository.findById(pondId)
                    .or(() -> pondRepository.findByDeviceId(pondId));
            if (pondOpt.isEmpty()) {
                return ResponseEntity.status(404).body(Map.of("error", "Pond not found"));
            }
            Pond pond = pondOpt.get();
            if (pond.getOwnerUsername() == null || !pond.getOwnerUsername().equals(username)) {
                return ResponseEntity.status(403).body(Map.of("error", "Invalid pond filter for current user"));
            }
            normalizedPondId = pond.getId();
        }

        List<FishDiseaseDiagnosis> diagnoses = normalizedPondId == null
                ? diagnosisRepository.findByUsernameOrderByDiagnosedAtDesc(username)
                : diagnosisRepository.findByUsernameAndPondIdOrderByDiagnosedAtDesc(username, normalizedPondId);

        List<Map<String, Object>> response = diagnoses.stream().map(d -> {
            Map<String, Object> row = new HashMap<>();
            row.put("id", d.getId());
            row.put("pondId", d.getPondId());
            row.put("pondName", d.getPondName());
            row.put("imageName", d.getImageName());
            row.put("label", d.getLabel());
            row.put("score", d.getScore());
            row.put("diagnosedAt", d.getDiagnosedAt() == null ? null : d.getDiagnosedAt().toString());
            return row;
        }).toList();

        return ResponseEntity.ok(response);
    }

    @GetMapping("/fish-disease")
    public ResponseEntity<Map<String, Object>> fishDiseaseUsage() {
        return ResponseEntity.badRequest().body(Map.of(
                "error", "Method not supported",
                "message", "Use POST multipart/form-data with field 'file'. pondId is optional."
        ));
    }
}

