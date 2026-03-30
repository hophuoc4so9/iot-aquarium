-- Script để thêm các cột custom thresholds vào bảng fish_species
-- Chạy script này trong MySQL Workbench hoặc phpMyAdmin

USE aquarium_db;

-- Thêm các cột mới nếu chưa tồn tại
ALTER TABLE fish_species 
ADD COLUMN IF NOT EXISTS custom_temp_min DOUBLE DEFAULT NULL AFTER details_url,
ADD COLUMN IF NOT EXISTS custom_temp_max DOUBLE DEFAULT NULL AFTER custom_temp_min,
ADD COLUMN IF NOT EXISTS custom_ph_min DOUBLE DEFAULT NULL AFTER custom_temp_max,
ADD COLUMN IF NOT EXISTS custom_ph_max DOUBLE DEFAULT NULL AFTER custom_ph_min,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE AFTER custom_ph_max;

-- Kiểm tra kết quả
DESCRIBE fish_species;

-- Xem một vài dòng dữ liệu mẫu
SELECT id, name_english, name_vietnamese, temp_range, ph_range, 
       custom_temp_min, custom_temp_max, custom_ph_min, custom_ph_max, is_active
FROM fish_species 
LIMIT 5;
