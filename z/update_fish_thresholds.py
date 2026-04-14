# -*- coding: utf-8 -*-
import mysql.connector
import re

# Cấu hình kết nối MySQL
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'root',
    'database': 'aquarium_db'
}

def parse_temperature_range(temp_range_str):
    """
    Parse temperature range string và trả về (min, max)
    Ví dụ: "22-25 °C" -> (22.0, 25.0)
           "72–77 °F" -> (22.2, 25.0) # Convert F to C
    """
    if not temp_range_str or temp_range_str.strip() == '':
        return None, None
    
    # Xóa các ký tự xuống dòng và khoảng trắng thừa
    temp_str = str(temp_range_str).strip().replace('\n', ' ')
    
    try:
        # ƯU TIÊN: Tìm giá trị Celsius trước (22–25 °C)
        celsius_match = re.search(r'(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)\s*°?\s*C', temp_str, re.IGNORECASE)
        if celsius_match:
            temp_min = float(celsius_match.group(1))
            temp_max = float(celsius_match.group(2))
            return round(temp_min, 1), round(temp_max, 1)
        
        # Nếu không có °C, tìm Fahrenheit (72–77 °F)
        fahrenheit_match = re.search(r'(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)\s*°?\s*F', temp_str, re.IGNORECASE)
        if fahrenheit_match:
            temp_min = (float(fahrenheit_match.group(1)) - 32) * 5.0 / 9.0
            temp_max = (float(fahrenheit_match.group(2)) - 32) * 5.0 / 9.0
            return round(temp_min, 1), round(temp_max, 1)
        
        # Fallback: Lấy 2 số đầu tiên (giả định là Celsius)
        numbers = re.findall(r'\d+\.?\d*', temp_str)
        if len(numbers) >= 2:
            temp_min = float(numbers[0])
            temp_max = float(numbers[1])
            return round(temp_min, 1), round(temp_max, 1)
            
    except Exception as e:
        print(f"  ⚠️ Không parse được temp range '{temp_str}': {e}")
    
    return None, None

def parse_ph_range(ph_range_str):
    """
    Parse pH range string và trả về (min, max)
    Ví dụ: "6.0-7.5" -> (6.0, 7.5)
           "5.5–6.8" -> (5.5, 6.8)
    """
    if not ph_range_str or ph_range_str.strip() == '':
        return None, None
    
    # Xóa các ký tự xuống dòng và khoảng trắng thừa
    ph_str = str(ph_range_str).strip().replace('\n', ' ')
    
    try:
        # Tìm các số thập phân trong chuỗi
        numbers = re.findall(r'\d+\.?\d*', ph_str)
        
        if len(numbers) >= 2:
            ph_min = float(numbers[0])
            ph_max = float(numbers[1])
            
            # Làm tròn 1 chữ số thập phân
            return round(ph_min, 1), round(ph_max, 1)
        elif len(numbers) == 1:
            # Chỉ có 1 giá trị, dùng làm cả min và max
            ph_val = float(numbers[0])
            return round(ph_val, 1), round(ph_val, 1)
    except Exception as e:
        print(f"  ⚠️ Không parse được pH range '{ph_str}': {e}")
    
    return None, None

def update_custom_thresholds():
    """Cập nhật các cột custom_temp_min/max và custom_ph_min/max từ temp_range và ph_range"""
    
    print("=" * 70)
    print("SCRIPT CẬP NHẬT NGƯỠNG CUSTOM TỪ DỮ LIỆU CŨ")
    print("=" * 70)
    
    # Kết nối MySQL
    print("\n✓ Đang kết nối tới MySQL...")
    conn = mysql.connector.connect(
        host=DB_CONFIG['host'],
        user=DB_CONFIG['user'],
        password=DB_CONFIG['password'],
        database=DB_CONFIG['database']
    )
    cursor = conn.cursor()
    print("✓ Đã kết nối thành công!")
    
    # Lấy tất cả các dòng có temp_range hoặc ph_range
    print("\n✓ Đang lấy dữ liệu từ database...")
    cursor.execute("""
        SELECT id, name_english, temp_range, ph_range 
        FROM fish_species 
        WHERE temp_range IS NOT NULL 
           OR ph_range IS NOT NULL
        ORDER BY id
    """)
    
    rows = cursor.fetchall()
    print(f"✓ Tìm thấy {len(rows)} dòng cần cập nhật\n")
    
    # Chuẩn bị câu lệnh UPDATE
    update_query = """
        UPDATE fish_species 
        SET custom_temp_min = %s,
            custom_temp_max = %s,
            custom_ph_min = %s,
            custom_ph_max = %s
        WHERE id = %s
    """
    
    success_count = 0
    temp_updated = 0
    ph_updated = 0
    
    print("=== BẮT ĐẦU CẬP NHẬT ===\n")
    
    for row in rows:
        fish_id, name_english, temp_range, ph_range = row
        
        print(f"[{fish_id}] {name_english}")
        
        # Parse temperature range
        temp_min, temp_max = parse_temperature_range(temp_range)
        if temp_min is not None:
            print(f"  🌡️  Nhiệt độ: {temp_min}°C - {temp_max}°C")
            temp_updated += 1
        
        # Parse pH range
        ph_min, ph_max = parse_ph_range(ph_range)
        if ph_min is not None:
            print(f"  📊  pH: {ph_min} - {ph_max}")
            ph_updated += 1
        
        # Thực hiện update
        try:
            cursor.execute(update_query, (
                temp_min,
                temp_max,
                ph_min,
                ph_max,
                fish_id
            ))
            success_count += 1
            print(f"  ✓ Đã cập nhật\n")
        except Exception as e:
            print(f"  ✗ Lỗi: {e}\n")
    
    # Commit thay đổi
    conn.commit()
    
    # Kết quả
    print("=" * 70)
    print("=== KẾT QUẢ CẬP NHẬT ===")
    print(f"✓ Số dòng đã cập nhật: {success_count}/{len(rows)}")
    print(f"  - Cập nhật nhiệt độ: {temp_updated} dòng")
    print(f"  - Cập nhật pH: {ph_updated} dòng")
    print("=" * 70)
    
    # Hiển thị một vài dòng mẫu
    print("\n=== XEM MẪU DỮ LIỆU ĐÃ CẬP NHẬT ===\n")
    cursor.execute("""
        SELECT id, name_english, 
               temp_range, custom_temp_min, custom_temp_max,
               ph_range, custom_ph_min, custom_ph_max
        FROM fish_species 
        WHERE custom_temp_min IS NOT NULL 
           OR custom_ph_min IS NOT NULL
        LIMIT 5
    """)
    
    sample_rows = cursor.fetchall()
    for row in sample_rows:
        fish_id, name, temp_range, temp_min, temp_max, ph_range, ph_min, ph_max = row
        print(f"[{fish_id}] {name}")
        print(f"  Temp range: {temp_range}")
        print(f"  → Custom: {temp_min}°C - {temp_max}°C")
        print(f"  pH range: {ph_range}")
        print(f"  → Custom: {ph_min} - {ph_max}\n")
    
    # Đóng kết nối
    cursor.close()
    conn.close()
    print("✓ Đã đóng kết nối MySQL.")
    
    return success_count

if __name__ == "__main__":
    print("\n⚠️  LƯU Ý:")
    print("Script này sẽ cập nhật các cột custom_temp_min, custom_temp_max,")
    print("custom_ph_min, custom_ph_max dựa vào temp_range và ph_range hiện có.\n")
    
    confirm = input("Bạn có muốn tiếp tục? (y/n): ")
    if confirm.lower() != 'y':
        print("Đã hủy!")
        exit(0)
    
    try:
        updated = update_custom_thresholds()
        print(f"\n✓ Hoàn tất! Đã cập nhật {updated} dòng.")
    except Exception as e:
        print(f"\n✗ Lỗi nghiêm trọng: {e}")
        import traceback
        traceback.print_exc()
        exit(1)
