package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.Telemetry;
import backend_iot_aquarium.backend_iot_aquarium.repository.PondRepository;
import backend_iot_aquarium.backend_iot_aquarium.repository.TelemetryRepository;
import backend_iot_aquarium.backend_iot_aquarium.service.MqttService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;

/**
 * REST API endpoints for controlling the aquarium system
 * Điều khiển hệ thống bể cá qua MQTT:
 * - Mode: AUTO/MANUAL
 * - Motor: FORWARD/BACKWARD/STOP
 * - Duty cycle: 0-1023
 */
@RestController
@RequestMapping("/api/control")
@CrossOrigin(origins = "*") // Allow web and mobile app to access
public class ControlController {

    private static final String SHARED_MODE_TOPIC = "aquarium/pump/mode";
    private static final String SHARED_CMD_TOPIC = "aquarium/pump/cmd";

    private final MqttService mqttService;
    private final TelemetryRepository telemetryRepository;
    private final PondRepository pondRepository;

    public ControlController(MqttService mqttService,
                             TelemetryRepository telemetryRepository,
                             PondRepository pondRepository) {
        this.mqttService = mqttService;
        this.telemetryRepository = telemetryRepository;
        this.pondRepository = pondRepository;
    }

    /**
     * Set mode AUTO or MANUAL
     * POST /api/control/mode?mode=AUTO
     * POST /api/control/mode?mode=MANUAL
     */
    @PostMapping("/mode")
    public ResponseEntity<String> setMode(
            @RequestParam("mode") String mode,
            @RequestParam(value = "pondId", required = false) Long pondId
    ) {
        String m = mode.equalsIgnoreCase("AUTO") ? "AUTO" : "MANUAL";
        publishMode(resolveTelemetryPondId(pondId), m);
        return ResponseEntity.ok("Mode set to " + m);
    }

    /**
     * Manual motor control
     * POST /api/control/motor?cmd=FORWARD
     * POST /api/control/motor?cmd=BACKWARD
     * POST /api/control/motor?cmd=STOP
     * POST /api/control/motor?cmd=DUTY&duty=512
     */
    @PostMapping("/motor")
    public ResponseEntity<String> manualMotor(
            @RequestParam("cmd") String cmd,
            @RequestParam(value = "duty", required = false) Integer duty,
            @RequestParam(value = "pondId", required = false) Long pondId
    ) {
        Long targetPondId = resolveTelemetryPondId(pondId);
        // Allowed commands: FORWARD, BACKWARD, STOP, DUTY
        String upper = cmd.toUpperCase();
        if (upper.equals("DUTY") && duty != null) {
            publishCommand(targetPondId, "DUTY:" + duty);
            return ResponseEntity.ok("DUTY set to " + duty);
        }
        if (upper.equals("FORWARD") || upper.equals("BACKWARD") || upper.equals("STOP")) {
            publishCommand(targetPondId, upper);
            return ResponseEntity.ok("Command sent: " + upper);
        }
        return ResponseEntity.badRequest().body("Invalid command");
    }

    /**
     * Get latest status/telemetry
     * GET /api/control/status/latest
     */
    @GetMapping("/status/latest")
    public ResponseEntity<Telemetry> latest(@RequestParam(value = "pondId", required = false) Long pondId) {
        Long telemetryPondId = resolveTelemetryPondId(pondId);
        Telemetry t = pondId == null
                ? telemetryRepository.findTopByOrderByTimestampDesc()
                : telemetryRepository.findTopByPondIdOrderByTimestampDesc(telemetryPondId);
        if (t == null) return ResponseEntity.noContent().build();
        return ResponseEntity.ok(t);
    }

    private Long resolveTelemetryPondId(Long requestedPondId) {
        if (requestedPondId == null) {
            return null;
        }
        return pondRepository.findById(requestedPondId)
                .map(p -> p.getDeviceId() != null ? p.getDeviceId() : p.getId())
                .orElse(requestedPondId);
    }

    private void publishMode(Long pondId, String mode) {
        mqttService.publish(SHARED_MODE_TOPIC, mode);
        if (pondId != null) {
            mqttService.publish(topicForPond(pondId, "mode"), mode);
        }
    }

    private void publishCommand(Long pondId, String command) {
        mqttService.publish(SHARED_CMD_TOPIC, command);
        if (pondId != null) {
            mqttService.publish(topicForPond(pondId, "cmd"), command);
        }
    }

    private String topicForPond(Long pondId, String kind) {
        return "aquarium/pond/" + pondId + "/pump/" + kind;
    }
}
