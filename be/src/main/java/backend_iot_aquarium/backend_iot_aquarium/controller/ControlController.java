package backend_iot_aquarium.backend_iot_aquarium.controller;

import backend_iot_aquarium.backend_iot_aquarium.model.Telemetry;
import backend_iot_aquarium.backend_iot_aquarium.repository.TelemetryRepository;
import backend_iot_aquarium.backend_iot_aquarium.service.MqttService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

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

    private final MqttService mqttService;
    private final TelemetryRepository telemetryRepository;

    public ControlController(MqttService mqttService, TelemetryRepository telemetryRepository) {
        this.mqttService = mqttService;
        this.telemetryRepository = telemetryRepository;
    }

    /**
     * Set mode AUTO or MANUAL
     * POST /api/control/mode?mode=AUTO
     * POST /api/control/mode?mode=MANUAL
     */
    @PostMapping("/mode")
    public ResponseEntity<String> setMode(@RequestParam("mode") String mode) {
        String m = mode.equalsIgnoreCase("AUTO") ? "AUTO" : "MANUAL";
        mqttService.publish("aquarium/pump/mode", m);
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
    public ResponseEntity<String> manualMotor(@RequestParam("cmd") String cmd, @RequestParam(value = "duty", required = false) Integer duty) {
        // Allowed commands: FORWARD, BACKWARD, STOP, DUTY
        String upper = cmd.toUpperCase();
        if (upper.equals("DUTY") && duty != null) {
            mqttService.publish("aquarium/pump/cmd", "DUTY:" + duty);
            return ResponseEntity.ok("DUTY set to " + duty);
        }
        if (upper.equals("FORWARD") || upper.equals("BACKWARD") || upper.equals("STOP")) {
            mqttService.publish("aquarium/pump/cmd", upper);
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
        Telemetry t = pondId == null
                ? telemetryRepository.findTopByOrderByTimestampDesc()
                : telemetryRepository.findTopByPondIdOrderByTimestampDesc(pondId);
        if (t == null) return ResponseEntity.noContent().build();
        return ResponseEntity.ok(t);
    }
}
