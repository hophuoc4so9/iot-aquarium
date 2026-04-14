# -*- coding: utf-8 -*-
import pandas as pd
import mysql.connector
from deep_translator import GoogleTranslator
import time
import os

# Cấu hình kết nối MySQL
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',  # Thay đổi username của bạn
    'password': 'root',  # Thay đổi password của bạn
    'database': 'aquarium_db'  # Thay đổi tên database của bạn
}

def create_database_and_table(cursor, db_name):
    """Tạo database và table nếu chưa tồn tại"""
    try:
        cursor.execute(f"CREATE DATABASE IF NOT EXISTS {db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
        print(f"Database '{db_name}' đã được tạo hoặc đã tồn tại.")
        cursor.execute(f"USE {db_name}")
        
        # Tạo bảng fish_species
        create_table_query = """
        CREATE TABLE IF NOT EXISTS fish_species (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name_english VARCHAR(255) NOT NULL,
            name_vietnamese VARCHAR(255),
            taxonomy VARCHAR(255),
            image_url TEXT,
            remarks TEXT,
            temp_range VARCHAR(100),
            ph_range VARCHAR(50),
            details_url TEXT,
            custom_temp_min DOUBLE DEFAULT NULL,
            custom_temp_max DOUBLE DEFAULT NULL,
            custom_ph_min DOUBLE DEFAULT NULL,
            custom_ph_max DOUBLE DEFAULT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_name_en (name_english),
            INDEX idx_name_vi (name_vietnamese)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """
        cursor.execute(create_table_query)
        print("Bảng 'fish_species' đã được tạo hoặc đã tồn tại.")
        
    except mysql.connector.Error as err:
        print(f"Lỗi khi tạo database/table: {err}")
        raise

def translate_to_vietnamese(text, max_retries=3):
    """Dịch text sang tiếng Việt với retry logic"""
    if pd.isna(text) or text.strip() == '':
        return None
    
    for attempt in range(max_retries):
        try:
            # Thêm delay để tránh rate limit
            time.sleep(0.5)
            translation = GoogleTranslator(source='en', target='vi').translate(text)
            return translation
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"Lỗi khi dịch '{text}': {e}. Thử lại lần {attempt + 2}...")
                time.sleep(2)
            else:
                print(f"Không thể dịch '{text}' sau {max_retries} lần thử. Giữ nguyên tên tiếng Anh.")
                return text
    return text

def parse_temperature_range(temp_range_str):
    """
    Parse temperature range string và trả về (min, max)
    Ví dụ: "22-25 °C" -> (22.0, 25.0)
           "72–77 °F" -> (22.2, 25.0) # Convert F to C
    """
    if pd.isna(temp_range_str) or temp_range_str.strip() == '':
        return None, None
    
    import re
    
    # Xóa các ký tự xuống dòng và khoảng trắng thừa
    temp_str = str(temp_range_str).strip().replace('\n', ' ')
    
    try:
        # Tìm các số trong chuỗi
        numbers = re.findall(r'\d+\.?\d*', temp_str)
        
        if len(numbers) >= 2:
            temp_min = float(numbers[0])
            temp_max = float(numbers[1])
            
            # Kiểm tra nếu là Fahrenheit thì convert sang Celsius
            if '°F' in temp_str or 'F' in temp_str:
                temp_min = (temp_min - 32) * 5.0 / 9.0
                temp_max = (temp_max - 32) * 5.0 / 9.0
            
            # Làm tròn 1 chữ số thập phân
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
    if pd.isna(ph_range_str) or ph_range_str.strip() == '':
        return None, None
    
    import re
    
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

def import_fish_data(csv_file_path):
    """Import dữ liệu cá từ CSV vào MySQL"""
    
    # Đọc file CSV
    print(f"Đang đọc file CSV: {csv_file_path}")
    df = pd.read_csv(csv_file_path, encoding='utf-8')
    print(f"Đã đọc {len(df)} dòng dữ liệu từ CSV")
    
    # Kết nối MySQL
    print("Đang kết nối tới MySQL...")
    conn = mysql.connector.connect(
        host=DB_CONFIG['host'],
        user=DB_CONFIG['user'],
        password=DB_CONFIG['password']
    )
    cursor = conn.cursor()
    
    # Tạo database và table
    create_database_and_table(cursor, DB_CONFIG['database'])
    
    # Chuẩn bị câu lệnh INSERT
    insert_query = """
    INSERT INTO fish_species 
    (name_english, name_vietnamese, taxonomy, image_url, remarks, temp_range, ph_range, details_url,
     custom_temp_min, custom_temp_max, custom_ph_min, custom_ph_max, is_active)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    
    # Dịch và insert dữ liệu
    success_count = 0
    error_count = 0
    
    print("\n=== BẮT ĐẦU IMPORT DỮ LIỆU ===\n")
    
    for index, row in df.iterrows():
        try:
            # Lấy tên tiếng Anh
            name_english = row['name'] if pd.notna(row['name']) else None
            
            if not name_english:
                print(f"Bỏ qua dòng {index + 1}: Không có tên cá")
                error_count += 1
                continue
            
            # Dịch tên sang tiếng Việt
            print(f"[{index + 1}/{len(df)}] Đang dịch: {name_english}...", end=' ')
            name_vietnamese = translate_to_vietnamese(name_english)
            print(f"=> {name_vietnamese}")
            
            # Parse temperature và pH ranges
            temp_range_str = row['temprange'] if pd.notna(row['temprange']) else None
            ph_range_str = row['phRange'] if pd.notna(row['phRange']) else None
            
            custom_temp_min, custom_temp_max = parse_temperature_range(temp_range_str)
            custom_ph_min, custom_ph_max = parse_ph_range(ph_range_str)
            
            # In thông tin parse được
            if custom_temp_min is not None:
                print(f"  🌡️ Temp: {custom_temp_min}°C - {custom_temp_max}°C")
            if custom_ph_min is not None:
                print(f"  📊 pH: {custom_ph_min} - {custom_ph_max}")
            
            # Chuẩn bị dữ liệu
            data = (
                name_english,
                name_vietnamese,
                row['taxonomy'] if pd.notna(row['taxonomy']) else None,
                row['imageURL'] if pd.notna(row['imageURL']) else None,
                row['remarks'] if pd.notna(row['remarks']) else None,
                temp_range_str,
                ph_range_str,
                row['detailsUrl'] if pd.notna(row['detailsUrl']) else None,
                custom_temp_min,
                custom_temp_max,
                custom_ph_min,
                custom_ph_max,
                True  # is_active
            )
            
            # Insert vào database
            cursor.execute(insert_query, data)
            success_count += 1
            
            # Commit mỗi 10 dòng để tránh mất dữ liệu
            if success_count % 10 == 0:
                conn.commit()
                print(f"  ✓ Đã lưu {success_count} dòng...")
            
        except Exception as e:
            print(f"  ✗ Lỗi tại dòng {index + 1}: {e}")
            error_count += 1
            continue
    
    # Commit những dòng còn lại
    conn.commit()
    
    # Kết quả
    print("\n=== KẾT QUẢ IMPORT ===")
    print(f"✓ Thành công: {success_count} dòng")
    print(f"✗ Lỗi: {error_count} dòng")
    print(f"Tổng cộng: {len(df)} dòng")
    
    # Đóng kết nối
    cursor.close()
    conn.close()
    print("\nĐã đóng kết nối MySQL.")
    
    return success_count, error_count

if __name__ == "__main__":
    # Đường dẫn file CSV
    csv_file = "freshwater_aquarium_fish_species.csv"
    
    # Kiểm tra file tồn tại
    if not os.path.exists(csv_file):
        print(f"Lỗi: Không tìm thấy file '{csv_file}'")
        print(f"Đường dẫn hiện tại: {os.getcwd()}")
        exit(1)
    
    print("=" * 60)
    print("SCRIPT IMPORT DỮ LIỆU CÁ VÀO MYSQL VÀ DỊCH SANG TIẾNG VIỆT")
    print("=" * 60)
    print(f"\nFile CSV: {csv_file}")
    print(f"Database: {DB_CONFIG['database']}")
    print(f"Host: {DB_CONFIG['host']}")
    print("\nLưu ý: Vui lòng cập nhật thông tin MySQL trong DB_CONFIG trước khi chạy!\n")
    
    # Xác nhận
    confirm = input("Bạn đã cập nhật thông tin MySQL? (y/n): ")
    if confirm.lower() != 'y':
        print("Vui lòng cập nhật thông tin MySQL trong file script và chạy lại!")
        exit(0)
    
    # Thực hiện import
    try:
        success, errors = import_fish_data(csv_file)
        print("\n✓ Import hoàn tất!")
    except Exception as e:
        print(f"\n✗ Lỗi nghiêm trọng: {e}")
        exit(1)
