package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.service.FederatedLearningService;
import backend_iot_aquarium.backend_iot_aquarium.service.FlIngestService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/fl")
@CrossOrigin(origins = "*")
public class FederatedLearningController {

    private final FederatedLearningService federatedLearningService;
    private final FlIngestService flIngestService;

    public FederatedLearningController(FederatedLearningService federatedLearningService,
                                       FlIngestService flIngestService) {
        this.federatedLearningService = federatedLearningService;
        this.flIngestService = flIngestService;
    }

    @PostMapping("/rounds/start")
    public ResponseEntity<Map<String, Object>> startRound(@RequestBody(required = false) Map<String, Object> body) {
        try {
            Map<String, Object> safeBody = body == null ? Map.of() : body;

            Long roundId = asLong(safeBody.get("roundId"));
            Integer deadlineSeconds = asInt(safeBody.get("deadlineSeconds"));
            Integer minClients = asInt(safeBody.get("minClients"));
            Integer minSamples = asInt(safeBody.get("minSamples"));
            Integer epochs = asInt(safeBody.get("epochs"));
            Integer samples = asInt(safeBody.get("samples"));
            List<Long> deviceIds = asLongList(safeBody.get("deviceIds"));

            Map<String, Object> result = federatedLearningService.startRound(
                    roundId,
                    deadlineSeconds,
                    minClients,
                    minSamples,
                    deviceIds,
                    epochs,
                    samples
            );
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(error(ex.getMessage(), 400));
        } catch (IllegalStateException ex) {
            return ResponseEntity.badRequest().body(error(ex.getMessage(), 400));
        }
    }

    @PostMapping("/rounds/{roundId}/aggregate")
    public ResponseEntity<Map<String, Object>> aggregateRound(@PathVariable("roundId") long roundId) {
        try {
            return ResponseEntity.ok(federatedLearningService.aggregateRound(roundId));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.status(404).body(error(ex.getMessage(), 404));
        } catch (IllegalStateException ex) {
            return ResponseEntity.badRequest().body(error(ex.getMessage(), 400));
        }
    }

    @GetMapping("/rounds")
    public ResponseEntity<List<Map<String, Object>>> listRounds() {
        return ResponseEntity.ok(federatedLearningService.listRounds());
    }

    @GetMapping("/rounds/history")
    public ResponseEntity<Map<String, Object>> listRoundsHistory(
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "page", required = false) Integer page,
            @RequestParam(value = "size", required = false) Integer size
    ) {
        return ResponseEntity.ok(federatedLearningService.listRoundsHistory(status, page, size));
    }

    @GetMapping("/rounds/{roundId}")
    public ResponseEntity<Map<String, Object>> getRound(@PathVariable("roundId") long roundId) {
        try {
            return ResponseEntity.ok(federatedLearningService.getRound(roundId));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.status(404).body(error(ex.getMessage(), 404));
        }
    }

    @GetMapping("/rounds/{roundId}/reports")
    public ResponseEntity<Map<String, Object>> getRoundReports(@PathVariable("roundId") long roundId) {
        return ResponseEntity.ok(federatedLearningService.getRoundReports(roundId));
    }

    @GetMapping("/rounds/{roundId}/stats")
    public ResponseEntity<Map<String, Object>> getRoundStats(@PathVariable("roundId") long roundId) {
        try {
            return ResponseEntity.ok(federatedLearningService.getRoundStats(roundId));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.status(404).body(error(ex.getMessage(), 404));
        }
    }

    @GetMapping("/models/latest")
    public ResponseEntity<Map<String, Object>> getLatestModel() {
        Map<String, Object> response = federatedLearningService.getLatestModel();
        Object statusCodeObj = response.get("statusCode");

        if (statusCodeObj instanceof Number number) {
            int statusCode = number.intValue();
            if (statusCode >= 400) {
                return ResponseEntity.status(statusCode).body(response);
            }
        }

        if (Boolean.FALSE.equals(response.get("success"))) {
            return ResponseEntity.status(404).body(response);
        }

        return ResponseEntity.ok(response);
    }

    @GetMapping("/runtime")
    public ResponseEntity<Map<String, Object>> getRuntimeStatus() {
        return ResponseEntity.ok(federatedLearningService.getRuntimeStatus());
    }

    @GetMapping("/devices/online")
    public ResponseEntity<Map<String, Object>> getOnlineDevices() {
        return ResponseEntity.ok(federatedLearningService.getOnlineDevices());
    }

    @PostMapping("/updates")
    public ResponseEntity<Map<String, Object>> uploadUpdate(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(flIngestService.ingestHttpUpdate(body));
    }

    private Long asLong(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.longValue();
        }
        try {
            return Long.parseLong(String.valueOf(value));
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private Integer asInt(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private List<Long> asLongList(Object value) {
        if (!(value instanceof List<?> list)) {
            return null;
        }

        return list.stream()
                .map(this::asLong)
                .filter(v -> v != null)
                .toList();
    }

    private Map<String, Object> error(String message, int statusCode) {
        return Map.of(
                "success", false,
                "error", message,
                "statusCode", statusCode
        );
    }
}
