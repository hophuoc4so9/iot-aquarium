# 🔄 Cập nhật Database Schema

## ⚠️ Lưu ý quan trọng

Database schema đã được cập nhật để hỗ trợ ngưỡng cảnh báo tùy chỉnh cho từng loài cá.

## 📋 Các cột mới

Đã thêm các cột sau vào bảng `fish_species`:

```sql
custom_temp_min DOUBLE DEFAULT NULL,
custom_temp_max DOUBLE DEFAULT NULL,
custom_ph_min DOUBLE DEFAULT NULL,
custom_ph_max DOUBLE DEFAULT NULL,
is_active BOOLEAN DEFAULT TRUE
```

## 🚀 Cách cập nhật

### Option 1: Xóa và tạo lại database (KHUYẾN NGHỊ)

```bash
# 1. Kết nối MySQL
mysql -u root -p

# 2. Xóa database cũ
DROP DATABASE IF EXISTS aquarium_db;

# 3. Thoát MySQL
exit;

# 4. Chạy lại script import
cd D:\DaiHoc\nam4\TH_IOT\iot-final-aquarium
python import_fish_to_db.py
```

### Option 2: Thêm cột vào bảng hiện có

Nếu không muốn mất dữ liệu:

```sql
USE aquarium_db;

ALTER TABLE fish_species 
ADD COLUMN custom_temp_min DOUBLE DEFAULT NULL AFTER details_url,
ADD COLUMN custom_temp_max DOUBLE DEFAULT NULL AFTER custom_temp_min,
ADD COLUMN custom_ph_min DOUBLE DEFAULT NULL AFTER custom_temp_max,
ADD COLUMN custom_ph_max DOUBLE DEFAULT NULL AFTER custom_ph_min,
ADD COLUMN is_active BOOLEAN DEFAULT TRUE AFTER custom_ph_max;
```

## ✅ Kiểm tra

Sau khi cập nhật, kiểm tra schema:

```sql
USE aquarium_db;
DESCRIBE fish_species;
```

Kết quả mong đợi:

```
+-------------------+--------------+------+-----+-------------------+
| Field             | Type         | Null | Key | Default           |
+-------------------+--------------+------+-----+-------------------+
| id                | int          | NO   | PRI | NULL              |
| name_english      | varchar(255) | NO   | MUL | NULL              |
| name_vietnamese   | varchar(255) | YES  | MUL | NULL              |
| taxonomy          | varchar(255) | YES  |     | NULL              |
| image_url         | text         | YES  |     | NULL              |
| remarks           | text         | YES  |     | NULL              |
| temp_range        | varchar(100) | YES  |     | NULL              |
| ph_range          | varchar(50)  | YES  |     | NULL              |
| details_url       | text         | YES  |     | NULL              |
| custom_temp_min   | double       | YES  |     | NULL              |
| custom_temp_max   | double       | YES  |     | NULL              |
| custom_ph_min     | double       | YES  |     | NULL              |
| custom_ph_max     | double       | YES  |     | NULL              |
| is_active         | tinyint(1)   | YES  |     | 1                 |
| created_at        | timestamp    | NO   |     | CURRENT_TIMESTAMP |
| updated_at        | timestamp    | NO   |     | CURRENT_TIMESTAMP |
+-------------------+--------------+------+-----+-------------------+
```

## 🔍 Kiểm tra dữ liệu

```sql
-- Đếm số lượng cá có đủ dữ liệu temp và pH
SELECT COUNT(*) as total_complete_fish
FROM fish_species 
WHERE temp_range IS NOT NULL 
  AND temp_range != '' 
  AND ph_range IS NOT NULL 
  AND ph_range != '';

-- Xem 5 loài cá đầu tiên
SELECT id, name_english, name_vietnamese, temp_range, ph_range
FROM fish_species
WHERE temp_range IS NOT NULL 
  AND temp_range != '' 
  AND ph_range IS NOT NULL 
  AND ph_range != ''
LIMIT 5;
```

## 🎯 Test API sau khi cập nhật

```bash
# 1. Lấy danh sách cá
curl http://localhost:8080/api/fish/list

# 2. Tìm cá "panda"
curl http://localhost:8080/api/fish/search?name=panda

# 3. Lấy thông tin chi tiết cá ID 1
curl http://localhost:8080/api/fish/1

# 4. Lấy ngưỡng mặc định
curl http://localhost:8080/api/fish/defaults
```

## 🐛 Troubleshooting

### Lỗi: "Table 'fish_species' doesn't exist"
→ Chạy lại script import: `python import_fish_to_db.py`

### Lỗi: "Unknown column 'custom_temp_min'"
→ Schema chưa được cập nhật, chạy ALTER TABLE hoặc xóa DB và import lại

### API trả về empty list
→ Kiểm tra dữ liệu có đủ temp_range và ph_range không

```sql
-- Kiểm tra cá thiếu dữ liệu
SELECT name_english, temp_range, ph_range
FROM fish_species
WHERE temp_range IS NULL 
   OR temp_range = '' 
   OR ph_range IS NULL 
   OR ph_range = '';
```

## ✨ Tính năng mới

Sau khi cập nhật, bạn có thể:

1. ✅ Tìm kiếm cá theo tên tiếng Anh/Việt
2. ✅ Xem ảnh và thông tin chi tiết
3. ✅ Cập nhật ngưỡng cảnh báo riêng cho từng loài
4. ✅ Reset về giá trị mặc định bất kỳ lúc nào
5. ✅ Chỉ hiển thị cá có đủ thông tin temp & pH

Enjoy! 🐠
