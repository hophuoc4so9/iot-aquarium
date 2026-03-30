import csv
import time
from pathlib import Path

from googletrans import Translator


BASE = Path(r"e:\Daihoc\nckh-2025\IOT-BeCa\iot-final-aquarium")

translator = Translator()


def safe_translate(text: str) -> str:
    """Dịch sang tiếng Việt, có xử lý lỗi và giới hạn tốc độ."""
    text = (text or "").strip()
    if not text:
        return ""
    try:
        res = translator.translate(text, src="en", dest="vi")
        # Nghỉ một chút để tránh bị giới hạn
        time.sleep(0.2)
        return res.text
    except Exception as e:
        print("Lỗi dịch:", e)
        return ""


def augment_species_info():
    """Dịch tên và ghi chú loài cá sang tiếng Việt."""
    src = BASE / "vn_fish_species_info.csv"
    dst = BASE / "vn_fish_species_info_vi.csv"

    with src.open(encoding="utf-8") as f_in, dst.open(
        "w", newline="", encoding="utf-8"
    ) as f_out:
        reader = csv.DictReader(f_in)
        fieldnames = list(reader.fieldnames)
        if "NameVietnamese" not in fieldnames:
            fieldnames.append("NameVietnamese")
        if "RemarksVietnamese" not in fieldnames:
            fieldnames.append("RemarksVietnamese")

        writer = csv.DictWriter(f_out, fieldnames=fieldnames)
        writer.writeheader()

        for i, row in enumerate(reader, start=1):
            eng_name = row.get("FBname", "")  # tên tiếng Anh (nếu có)
            # một số cột mô tả/ghi chú trong species
            remarks = (
                row.get("Comments", "")
                or row.get("Remark", "")
                or row.get("Profile", "")
            )

            row["NameVietnamese"] = safe_translate(eng_name)
            row["RemarksVietnamese"] = safe_translate(remarks)

            writer.writerow(row)

            if i % 50 == 0:
                print(f"[species_info] Đã dịch {i} dòng...")

    print("Đã tạo xong vn_fish_species_info_vi.csv")


def augment_ecology():
    """Dịch mô tả điều kiện môi trường sang tiếng Việt."""
    src = BASE / "vn_fish_ecology.csv"
    dst = BASE / "vn_fish_ecology_vi.csv"

    with src.open(encoding="utf-8") as f_in, dst.open(
        "w", newline="", encoding="utf-8"
    ) as f_out:
        reader = csv.DictReader(f_in)
        fieldnames = list(reader.fieldnames)
        if "MoTaDieuKienVi" not in fieldnames:
            fieldnames.append("MoTaDieuKienVi")

        writer = csv.DictWriter(f_out, fieldnames=fieldnames)
        writer.writeheader()

        for i, row in enumerate(reader, start=1):
            # Nếu ecology có cột mô tả, ta dịch; nếu không, tự tạo mô tả từ số liệu
            desc = row.get("Comments", "") or row.get("Ecology", "") or ""

            if not desc:
                tmin = row.get("TempMin") or row.get("Tempmin") or ""
                tmax = row.get("TempMax") or row.get("Tempmax") or ""
                phmin = row.get("pHMin") or row.get("PHMin") or ""
                phmax = row.get("pHMax") or row.get("PHMax") or ""

                parts = []
                if tmin and tmax:
                    parts.append(f"Nhiệt độ thích hợp khoảng {tmin}–{tmax}°C")
                if phmin and phmax:
                    parts.append(f"pH thích hợp khoảng {phmin}–{phmax}")
                desc = "; ".join(parts)

            row["MoTaDieuKienVi"] = safe_translate(desc) if desc else ""
            writer.writerow(row)

            if i % 50 == 0:
                print(f"[ecology] Đã dịch {i} dòng...")

    print("Đã tạo xong vn_fish_ecology_vi.csv")


if __name__ == "__main__":
    augment_species_info()
    augment_ecology()
    print("Hoàn tất dịch dữ liệu cá sang tiếng Việt (tự động)")


