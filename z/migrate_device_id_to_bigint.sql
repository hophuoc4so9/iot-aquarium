-- Migrate device_id from string to numeric Long/int across current aquarium tables.
-- Assumes the unified device ID for the ESP32 is 5.
-- Run this manually once on the existing aquarium_db before/after redeploying the backend.

USE aquarium_db;

-- Delete telemetry records with legacy string device IDs (old test data).
DELETE FROM telemetry WHERE device_id LIKE 'esp32-%' OR device_id NOT REGEXP '^[0-9]+$' OR device_id IS NULL;

-- Delete device_ownerships with invalid device IDs (can't have NULL).
DELETE FROM device_ownerships WHERE device_id LIKE 'esp32-%' OR device_id NOT REGEXP '^[0-9]+$' OR device_id IS NULL;

-- Set ponds.last_device_id to NULL for invalid legacy string values.
UPDATE ponds SET last_device_id = NULL WHERE last_device_id LIKE 'esp32-%' OR last_device_id NOT REGEXP '^[0-9]+$';

-- Change column types to BIGINT.
ALTER TABLE telemetry MODIFY COLUMN device_id BIGINT NULL;
ALTER TABLE device_ownerships MODIFY COLUMN device_id BIGINT NOT NULL;
ALTER TABLE ponds MODIFY COLUMN last_device_id BIGINT NULL;

-- Optional check.
SELECT id, device_id, pond_id, timestamp FROM telemetry ORDER BY id DESC LIMIT 5;
SELECT id, device_id, owner_username, created_at FROM device_ownerships ORDER BY id DESC LIMIT 5;
SELECT id, mqtt_pond_id, last_device_id, last_telemetry_at FROM ponds ORDER BY id DESC LIMIT 5;
