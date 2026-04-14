# FL Runtime Test Checklist (ESP32)

## 1. Build and Flash
- Run `pio run` in `iot/` and confirm build success.
- Flash firmware to ESP32-S3 and open serial monitor (`pio device monitor -b 115200`).
- Confirm boot logs include WiFi connect, MQTT connect, and DS18B20 detection status.

### Optional quick smoke script
- Install dependency once: `pip install paho-mqtt`
- Run automated smoke test (requires online ESP32 device):
  - `python iot/test/fl_mqtt_smoke_test.py --broker broker.emqx.io --device-id 5 --pond-id 5`

## 2. MQTT Connectivity
- Stop internet/WiFi temporarily, then restore it.
- Verify device reconnects to WiFi and MQTT automatically.
- Confirm subscriptions are active again for:
  - `aquarium/pump/cmd`
  - `aquarium/pump/mode`
  - `aquarium/pond/{pondId}/pump/cmd`
  - `aquarium/pond/{pondId}/pump/mode`
  - `fl/model/{deviceId}/train/start`
  - `fl/model/{deviceId}/download`

## 3. Motor Command Flow
- Publish `FORWARD`, `BACKWARD`, `STOP`, and `DUTY:<0..1023>` commands.
- Validate direction pin behavior and PWM duty updates while running.
- Confirm immediate status telemetry after each command.

## 4. Auto Mode Safety
- Publish mode `AUTO` and simulate low float condition.
- Verify motor starts forward when low level is detected.
- Simulate high float condition and verify short reverse burst then stop.
- Validate safety timeout (`MOTOR_MAX_RUN_MS`) stops motor in both AUTO and MANUAL.

## 5. Telemetry Buffering
- Disconnect MQTT while sensor loop is running, then reconnect.
- Confirm telemetry is buffered locally and flushed after reconnection.
- Verify each payload has expected fields: `temperature`, `waterLevelPercent`, `anomalyScore`, `anomalyFlag`, `duty`, `mode`, `uptime_ms`.

## 6. Federated Learning Round
- Trigger training via topic `fl/model/{deviceId}/train/start` with payload:
  - `ROUND:101|SAMPLES:24|EPOCHS:2`
- Confirm train result is published to:
  - `fl/model/{deviceId}/train/done`
  - `fl/metrics/{deviceId}/report`
- Ensure payload includes `roundId`, `loss`, `sampleCount`, `shape`, `weights`.

## 7. Model Download Validation
- Publish valid update on `fl/model/{deviceId}/download`:
  - `VERSION:<new>|WEIGHTS:w0,w1,w2,w3|WCRC:<crc32_hex>`
- Confirm model applies and persists after reboot.
- Publish invalid CRC and confirm rejection.
- Publish lower/same version and confirm anti-downgrade rejection.
- Publish a model that causes strong regression and confirm rollback gate rejection.

## 8. Persistence and Reboot
- After successful model apply, reboot ESP32.
- Verify startup log shows model restored from NVS with expected version.
- Run one new train round and confirm device reports the restored version baseline.
