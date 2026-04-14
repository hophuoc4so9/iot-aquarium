-- Rename the pond hardware key column to device_id so the code and DB use one unified name.
-- Run this once on aquarium_db after backing up data.

USE aquarium_db;

-- If the old column exists, rename it to the unified name.
-- MySQL 8 supports RENAME COLUMN.
ALTER TABLE ponds RENAME COLUMN mqtt_pond_id TO device_id;

-- Keep a quick sanity check.
DESCRIBE ponds;
SELECT id, device_id, name, owner_username FROM ponds LIMIT 10;
