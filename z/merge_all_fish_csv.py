import csv
import re
from pathlib import Path


def normalize_scientific_name(name: str) -> str:
    if not name:
        return ""
    name = name.replace("_", " ")
    name = re.sub(r"\s+", " ", name)
    name = re.sub(r"[\(\)\[\]]", " ", name)
    name = re.sub(r"\s+", " ", name)
    return name.strip().lower()


def read_csv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        headers = reader.fieldnames or []
    return rows, headers


def write_csv(path: Path, rows, headers):
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)


def load_index_by_speccode(rows, spec_col="SpecCode"):
    index = {}
    for r in rows:
        spec = (r.get(spec_col) or "").strip()
        if not spec:
            continue
        try:
            key = int(spec)
        except ValueError:
            continue
        index[key] = r
    return index


def normalize_common_name(name: str) -> str:
    if not name:
        return ""
    name = name.strip().lower()
    name = re.sub(r"\s+", " ", name)
    return name


def main():
    project_root = Path(__file__).resolve().parents[0]
    data_dir = project_root / "be" / "src" / "main" / "resources" / "data"

    print("Data dir:", data_dir)

    # ===== 1. Load Wikipedia VN names từ file wiki_fish_names.csv =====
    wiki_csv = project_root / "wiki_fish_names.csv"
    wiki_map: dict[str, str] = {}
    if wiki_csv.exists():
        rows, headers = read_csv(wiki_csv)
        sci_col = "ScientificName"
        vn_col = "VietnameseName"
        if sci_col in headers and vn_col in headers:
            for r in rows:
                sci_raw = (r.get(sci_col) or "").strip()
                vn_raw = (r.get(vn_col) or "").strip()
                if not sci_raw or not vn_raw:
                    continue
                key = normalize_scientific_name(sci_raw)
                if key and key not in wiki_map:
                    wiki_map[key] = vn_raw
        print(f"Loaded {len(wiki_map)} scientific→VN name pairs from wiki_fish_names.csv.")
    else:
        print("WARNING: wiki_fish_names.csv not found. Continue without Wikipedia-based names.")

    # ===== 2. Load all CSVs =====
    info_path = data_dir / "vn_fish_species_info.csv"
    info_vi_path = data_dir / "vn_fish_species_info_vi.csv"
    eco_path = data_dir / "vn_fish_ecology.csv"
    eco_vi_path = data_dir / "vn_fish_ecology_vi.csv"
    vn_list_path = data_dir / "vn_fish_species_list.csv"
    fw_aqua_path = data_dir / "freshwater_aquarium_fish_species.csv"

    info_rows, info_headers = read_csv(info_path)
    info_index = load_index_by_speccode(info_rows, spec_col="SpecCode")

    info_vi_rows, info_vi_headers = read_csv(info_vi_path)
    info_vi_index = load_index_by_speccode(info_vi_rows, spec_col="SpecCode")

    eco_rows, eco_headers = read_csv(eco_path)
    eco_index = load_index_by_speccode(eco_rows, spec_col="SpecCode")

    eco_vi_rows, eco_vi_headers = read_csv(eco_vi_path)
    eco_vi_index = load_index_by_speccode(eco_vi_rows, spec_col="SpecCode")

    vn_list_rows, vn_list_headers = read_csv(vn_list_path)
    vn_list_index = load_index_by_speccode(vn_list_rows, spec_col="SpecCode")

    fw_aqua_rows, fw_aqua_headers = read_csv(fw_aqua_path)

    # Index aquarium file theo tên khoa học & tên thường gọi
    fw_by_sci = {}
    fw_by_common = {}

    # TODO: đổi tên cột nếu khác
    FW_SCI_COL = "ScientificName"  # hoặc "taxonomy"
    FW_COMMON_COL = "CommonName"

    for r in fw_aqua_rows:
        sci = normalize_scientific_name(r.get(FW_SCI_COL, ""))
        if sci:
            fw_by_sci[sci] = r
        cn = normalize_common_name(r.get(FW_COMMON_COL, ""))
        if cn:
            fw_by_common[cn] = r

    print(f"Base info rows: {len(info_rows)}")

    # ===== 3. Chuẩn bị header cho file gộp =====
    merged_headers = []

    def add_headers_with_prefix(headers, prefix):
        for h in headers:
            if not h:
                continue
            col = f"{prefix}{h}"
            if col not in merged_headers:
                merged_headers.append(col)

    add_headers_with_prefix(info_headers, "info_")
    add_headers_with_prefix(info_vi_headers, "info_vi_")
    add_headers_with_prefix(eco_headers, "eco_")
    add_headers_with_prefix(eco_vi_headers, "eco_vi_")
    add_headers_with_prefix(vn_list_headers, "vnlist_")
    add_headers_with_prefix(fw_aqua_headers, "aqua_")

    # Thêm cột tổng hợp
    extra_cols = [
        "merged_SpecCode",
        "merged_ScientificName",
        "merged_FBname",
        "merged_NameVietnamese",
        "merged_NameVietnameseSource",  # vi_file / wiki / aquarium / none
    ]
    for c in extra_cols:
        if c not in merged_headers:
            merged_headers.insert(0, c)

    merged_rows = []

    # ===== 4. Gộp theo SpecCode từ file info gốc =====
    for spec_key, base in info_index.items():
        merged = {h: "" for h in merged_headers}

        # ---------- info (EN) ----------
        for h in info_headers:
            col = f"info_{h}"
            merged[col] = base.get(h, "")

        spec_str = base.get("SpecCode", "").strip()
        merged["merged_SpecCode"] = spec_str

        genus = (base.get("Genus") or "").strip()
        species = (base.get("Species") or "").strip()
        sci_name = f"{genus} {species}".strip()
        merged["merged_ScientificName"] = sci_name

        merged["merged_FBname"] = (base.get("FBname") or "").strip()

        # ---------- info_vi ----------
        vi_row = info_vi_index.get(spec_key)
        if vi_row:
            for h in info_vi_headers:
                col = f"info_vi_{h}"
                merged[col] = vi_row.get(h, "")

        # ---------- ecology ----------
        eco_row = eco_index.get(spec_key)
        if eco_row:
            for h in eco_headers:
                col = f"eco_{h}"
                merged[col] = eco_row.get(h, "")

        # ---------- ecology_vi ----------
        eco_vi_row = eco_vi_index.get(spec_key)
        if eco_vi_row:
            for h in eco_vi_headers:
                col = f"eco_vi_{h}"
                merged[col] = eco_vi_row.get(h, "")

        # ---------- vn_fish_species_list ----------
        vn_list_row = vn_list_index.get(spec_key)
        if vn_list_row:
            for h in vn_list_headers:
                col = f"vnlist_{h}"
                merged[col] = vn_list_row.get(h, "")

        # ---------- aquarium (by scientific name) ----------
        if sci_name:
            norm_sci = normalize_scientific_name(sci_name)
            fw_row = fw_by_sci.get(norm_sci)
        else:
            fw_row = None

        if fw_row:
            for h in fw_aqua_headers:
                col = f"aqua_{h}"
                merged[col] = fw_row.get(h, "")

        # ===== 5. Tự quyết định NameVietnamese tổng =====
        vn_name = ""
        source = "none"

        # 5.1: ưu tiên file vi chính thức (NameVietnamese / RemarksVietnamese)
        # TODO: chỉnh tên cột nếu file vi của bạn khác
        if vi_row:
            vn_from_vi = (vi_row.get("NameVietnamese") or "").strip()
            if vn_from_vi and vn_from_vi != "0":
                vn_name = vn_from_vi
                source = "info_vi"

        # 5.2: nếu chưa có, thử Wikipedia theo tên khoa học
        if not vn_name and sci_name:
            norm_sci = normalize_scientific_name(sci_name)
            wiki_vn = wiki_map.get(norm_sci)
            if wiki_vn:
                vn_name = wiki_vn
                source = "wiki"

        # 5.3: nếu vẫn chưa, thử tên thường gọi aquarium (CommonName) nếu là tiếng Việt
        if not vn_name and fw_row:
            cn = (fw_row.get(FW_COMMON_COL) or "").strip()
            # Ở đây không check EN/VN, bạn có thể tự nhìn dữ liệu và thêm filter
            if cn and cn != "0":
                vn_name = cn
                source = "aquarium_common"

        merged["merged_NameVietnamese"] = vn_name
        merged["merged_NameVietnameseSource"] = source

        merged_rows.append(merged)

    # ===== 6. Ghi file gộp =====
    out_path = data_dir / "merged_fish_dataset.csv"
    write_csv(out_path, merged_rows, merged_headers)
    print(f"Saved merged dataset to: {out_path}")
    print(f"Total merged rows: {len(merged_rows)}")


if __name__ == "__main__":
    main()