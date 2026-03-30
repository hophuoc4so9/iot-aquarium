# Fish Species Management API

## 📋 Tổng quan

API quản lý các loài cá với khả năng:
- ✅ Tìm kiếm theo tên tiếng Anh hoặc tiếng Việt
- ✅ Hiển thị thông tin cá (hình ảnh, nhiệt độ, pH phù hợp)
- ✅ Cập nhật ngưỡng cảnh báo tùy chỉnh cho từng loài
- ✅ Reset về giá trị mặc định
- ✅ Chỉ hiển thị cá có đủ thông tin nhiệt độ và pH

## 🚀 Các API Endpoints

### 1. Lấy danh sách tất cả các loài cá (có đủ dữ liệu)

```http
GET /api/fish/list
```

**Response:**
```json
[
  {
    "id": 1,
    "nameEnglish": "Panda corydoras",
    "nameVietnamese": "Cá chuột gấu trúc",
    "taxonomy": "Corydoras panda",
    "imageUrl": "https://...",
    "tempRange": "22-26°C",
    "phRange": "6.0-8.0",
    "customTempMin": null,
    "customTempMax": null,
    "customPhMin": null,
    "customPhMax": null,
    "isActive": true
  }
]
```

### 2. Tìm kiếm cá theo tên

```http
GET /api/fish/search?name=panda
GET /api/fish/search?name=cá chuột
```

**Parameters:**
- `name` (optional): Tên cá để tìm kiếm (tiếng Anh hoặc tiếng Việt)

**Response:** Giống như `/api/fish/list`

### 3. Lấy thông tin chi tiết một loài cá

```http
GET /api/fish/{id}
```

**Response:**
```json
{
  "fish": {
    "id": 1,
    "nameEnglish": "Panda corydoras",
    "nameVietnamese": "Cá chuột gấu trúc",
    "taxonomy": "Corydoras panda",
    "imageUrl": "https://...",
    "tempRange": "22-26°C",
    "phRange": "6.0-8.0",
    "customTempMin": 22.0,
    "customTempMax": 26.0,
    "customPhMin": 6.5,
    "customPhMax": 7.5
  },
  "effectiveThresholds": {
    "tempMin": 22.0,
    "tempMax": 26.0,
    "phMin": 6.5,
    "phMax": 7.5
  },
  "usingCustom": true
}
```

### 4. Cập nhật ngưỡng cảnh báo tùy chỉnh

```http
PUT /api/fish/{id}/thresholds
Content-Type: application/json

{
  "tempMin": 22.0,
  "tempMax": 26.0,
  "phMin": 6.5,
  "phMax": 7.5
}
```

**Notes:**
- Có thể truyền `null` cho bất kỳ giá trị nào để sử dụng mặc định
- Nếu không truyền một trường, nó sẽ giữ nguyên giá trị hiện tại

**Response:**
```json
{
  "success": true,
  "message": "Alert thresholds updated successfully",
  "fish": { ... },
  "effectiveThresholds": {
    "tempMin": 22.0,
    "tempMax": 26.0,
    "phMin": 6.5,
    "phMax": 7.5
  }
}
```

### 5. Reset về ngưỡng mặc định

```http
POST /api/fish/{id}/reset
```

**Response:**
```json
{
  "success": true,
  "message": "Alert thresholds reset to default values",
  "fish": { ... },
  "defaultThresholds": {
    "tempMin": 18.0,
    "tempMax": 30.0,
    "phMin": 6.0,
    "phMax": 8.5
  }
}
```

### 6. Lấy ngưỡng mặc định của hệ thống

```http
GET /api/fish/defaults
```

**Response:**
```json
{
  "tempMin": 18.0,
  "tempMax": 30.0,
  "phMin": 6.0,
  "phMax": 8.5
}
```

## 🌐 Web Interface

### Tính năng

1. **Tìm kiếm cá**
   - Tìm theo tên tiếng Anh hoặc tiếng Việt
   - Hiển thị hình ảnh, tên, nhiệt độ và pH phù hợp

2. **Xem thông tin chi tiết**
   - Click vào card cá để xem chi tiết
   - Hiển thị ảnh lớn, thông tin đầy đủ
   - Hiển thị ngưỡng cảnh báo hiện tại

3. **Cập nhật ngưỡng**
   - Nhập giá trị tùy chỉnh cho temp min/max, pH min/max
   - Lưu và áp dụng ngưỡng mới

4. **Reset về mặc định**
   - Một nút để reset tất cả ngưỡng về giá trị hệ thống

## 🗄️ Database Schema

```sql
CREATE TABLE fish_species (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name_english VARCHAR(255) NOT NULL,
    name_vietnamese VARCHAR(255),
    taxonomy VARCHAR(255),
    image_url TEXT,
    remarks TEXT,
    temp_range VARCHAR(100),
    ph_range VARCHAR(50),
    details_url TEXT,
    
    -- Custom alert thresholds (nullable = use defaults)
    custom_temp_min DOUBLE DEFAULT NULL,
    custom_temp_max DOUBLE DEFAULT NULL,
    custom_ph_min DOUBLE DEFAULT NULL,
    custom_ph_max DOUBLE DEFAULT NULL,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_name_en (name_english),
    INDEX idx_name_vi (name_vietnamese)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## 📊 Logic ngưỡng cảnh báo

- **Nếu có custom threshold:** Sử dụng giá trị custom
- **Nếu custom = null:** Sử dụng giá trị mặc định từ `application.properties`

Ví dụ:
```
System defaults: tempMin=18°C, tempMax=30°C
Fish custom: tempMin=22°C, tempMax=null

=> Effective thresholds: tempMin=22°C (custom), tempMax=30°C (default)
```

## 🔧 Cài đặt và chạy

### 1. Import dữ liệu cá vào database

```bash
cd d:\DaiHoc\nam4\TH_IOT\iot-final-aquarium
python import_fish_to_db.py
```

### 2. Chạy backend

```bash
cd backend_iot_aquarium
mvn spring-boot:run
```

### 3. Chạy web interface

```bash
cd web-iot
npm install
npm run dev
```

Truy cập: http://localhost:5173

## 📝 Ví dụ sử dụng

### Tìm cá "panda"

```bash
curl http://localhost:8080/api/fish/search?name=panda
```

### Cập nhật ngưỡng cho cá ID 1

```bash
curl -X PUT http://localhost:8080/api/fish/1/thresholds \
  -H "Content-Type: application/json" \
  -d '{
    "tempMin": 22.0,
    "tempMax": 26.0,
    "phMin": 6.5,
    "phMax": 7.5
  }'
```

### Reset ngưỡng về mặc định

```bash
curl -X POST http://localhost:8080/api/fish/1/reset
```

## 🎯 Lưu ý quan trọng

1. **Chỉ hiển thị cá có đủ dữ liệu:**
   - API tự động lọc chỉ hiển thị cá có `tempRange` và `phRange` không rỗng
   - Đảm bảo người dùng chỉ thấy những cá có thể cấu hình ngưỡng

2. **Ngưỡng mặc định:**
   - Được cấu hình trong `application.properties`
   - Áp dụng cho tất cả các cá chưa có custom threshold

3. **Web responsive:**
   - Giao diện responsive, hoạt động tốt trên mobile
   - Grid layout tự động điều chỉnh số cột

## 🐛 Troubleshooting

### Không hiển thị cá nào
- Kiểm tra database đã có dữ liệu chưa
- Chạy lại script import: `python import_fish_to_db.py`

### API trả về lỗi 404
- Kiểm tra backend đã chạy chưa
- Kiểm tra port 8080 có bị chiếm không

### Không load được ảnh cá
- Một số link ảnh từ Wikipedia có thể bị lỗi
- Đây là vấn đề từ nguồn dữ liệu, không ảnh hưởng chức năng

## 📞 Support

Nếu có vấn đề, kiểm tra:
- Backend logs: Console Spring Boot
- Frontend logs: Browser DevTools Console
- Database: Kết nối MySQL đúng chưa
