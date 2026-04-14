import csv
import re
from pathlib import Path
from bs4 import BeautifulSoup

# ĐƯỜNG DẪN FILE HTML LƯU TỪ WIKIPEDIA
HTML_PATH = Path("wiki_freshwater_fish.html")
OUT_CSV = Path("wiki_fish_names.csv")

def normalize_scientific_name(name: str) -> str:
    if not name:
        return ""
    name = name.replace("_", " ")
    name = re.sub(r"\s+", " ", name)
    name = re.sub(r"[\(\)\[\]]", " ", name)
    name = re.sub(r"\s+", " ", name)
    return name.strip()

def main():
    html = HTML_PATH.read_text(encoding="utf-8")
    soup = BeautifulSoup(html, "html.parser")

    mapping = {}  # scientific -> vietnamese/common

    # Tất cả các bảng trong nội dung bài
    content = soup.find(id="mw-content-text") or soup
    tables = content.select("table")

    for tbl in tables:
        # Chỉ lấy các bảng có header dạng danh sách (Tên thường gọi / Tên khoa học / Loài / Taxonomy)
        header_row = tbl.find("tr")
        if not header_row:
            continue
        header_cells = [c.get_text(strip=True) for c in header_row.find_all(["th", "td"])]
        if not header_cells:
            continue

        # Tìm cột VN (Tên thường gọi / Tên thông thường / Tên / Common name)
        vn_idx = None
        sci_idx = None

        for i, text in enumerate(header_cells):
            t = text.lower()
            if "tên khoa học" in t or "loài" == t or "taxonomy" in t:
                sci_idx = i
            if "tên thường gọi" in t or "tên thông thường" in t or t == "tên" or "common name" in t:
                vn_idx = i

        # Nếu không có cột tên khoa học + ít nhất 1 cột tên thường, bỏ qua
        if sci_idx is None:
            continue
        if vn_idx is None:
            # fallback: lấy cột 0 làm tên thường (đa số bảng: cột 0 = tên VN)
            vn_idx = 0

        rows = tbl.find_all("tr")[1:]
        for tr in rows:
            cells = tr.find_all(["td", "th"])
            if len(cells) <= max(vn_idx, sci_idx):
                continue

            vn_name = cells[vn_idx].get_text(" ", strip=True)
            sci_cell = cells[sci_idx]

            # tên khoa học thường nằm trong <i>...</i>
            sci_i = sci_cell.find("i")
            if sci_i:
                sci_text = sci_i.get_text(" ", strip=True)
            else:
                sci_text = sci_cell.get_text(" ", strip=True)

            sci_text = normalize_scientific_name(sci_text)
            if not sci_text or " " not in sci_text:
                continue
            if not vn_name:
                continue

            # Lưu, không overwrite bản ghi cũ
            if sci_text not in mapping:
                mapping[sci_text] = vn_name

    print(f"Collected {len(mapping)} scientific→VN name pairs from local HTML.")

    # Ghi CSV
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["ScientificName", "VietnameseName"])
        for sci, vn in sorted(mapping.items()):
            writer.writerow([sci, vn])

    print(f"Saved to {OUT_CSV}")

if __name__ == "__main__":
    main()