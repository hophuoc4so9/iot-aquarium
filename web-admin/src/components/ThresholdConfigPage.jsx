import React, { useState, useEffect } from "react";
import { getPonds } from "../lib/storage";

const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

const DEFAULT_TH = {
  waterLow: 20,
  waterHigh: 85,
  phLow: 6.8,
  phHigh: 8.0,
  tempLow: 18,
  tempHigh: 30,
};

// Lưu riêng theo ao để không ảnh hưởng tới cấu hình nhanh trong Dashboard
const STORAGE_KEY = "aq-thresholds-by-pond";

function getThresholdsByPond() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function saveThresholdsByPond(byPond) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(byPond));
}

export default function ThresholdConfigPage() {
  const [byPond, setByPond] = useState({});
  const [ponds, setPonds] = useState([]);
  const [selectedPondId, setSelectedPondId] = useState("default");
  const [form, setForm] = useState(DEFAULT_TH);
  const [fishSamples, setFishSamples] = useState([]);
  const [fishList, setFishList] = useState([]);
  const [fishLoading, setFishLoading] = useState(false);
  const [searchName, setSearchName] = useState("");
  const [page, setPage] = useState(0);
  const [pageSize] = useState(20);
  const [totalPages, setTotalPages] = useState(0);

  useEffect(() => {
    setPonds(getPonds());
    setByPond(getThresholdsByPond());
    fetchFishSamples();
    fetchFishList(0, "");
  }, []);

  useEffect(() => {
    const th = byPond[selectedPondId] || DEFAULT_TH;
    setForm({ ...DEFAULT_TH, ...th });
  }, [selectedPondId, byPond]);

  const handleSave = () => {
    const next = { ...byPond, [selectedPondId]: { ...form } };
    setByPond(next);
    saveThresholdsByPond(next);
  };

  async function fetchFishSamples() {
    try {
      const res = await fetch(`${API_BASE}/api/fish/configured?page=0&size=6`);
      if (!res.ok) return;
      const data = await res.json();
      const list = Array.isArray(data) ? data : data.content ?? [];
      setFishSamples(list);
    } catch (e) {
      console.error("Failed to fetch fish samples", e);
    }
  }

  async function fetchFishList(targetPage, nameFilter) {
    setFishLoading(true);
    try {
      const params = new URLSearchParams({
        page: String(targetPage),
        size: String(pageSize),
      });
      if (nameFilter && nameFilter.trim() !== "") {
        params.set("name", nameFilter.trim());
      }
      const res = await fetch(`${API_BASE}/api/fish/configured?${params.toString()}`);
      if (!res.ok) return;
      const data = await res.json();
      const content = Array.isArray(data) ? data : data.content ?? [];
      setFishList(content);
      setTotalPages(data.totalPages ?? 1);
      setPage(targetPage);
    } catch (e) {
      console.error("Failed to fetch fish thresholds list", e);
    } finally {
      setFishLoading(false);
    }
  }

  const pondOptions = [{ id: "default", name: "Mặc định (toàn hệ thống)" }, ...ponds];

  return (
    <div className="w-full h-full flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-semibold text-slate-800">
            Cấu hình ngưỡng cảnh báo
          </h2>
          <p className="text-sm text-slate-500 mt-1 max-w-2xl">
            Thiết lập ngưỡng an toàn cho từng ao. Hệ thống sẽ dùng ngưỡng này để
            đánh giá cảnh báo, kết hợp với ngưỡng khuyến nghị theo loài cá.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <label className="text-sm text-slate-600">Áp dụng cho ao:</label>
          <select
            value={selectedPondId}
            onChange={(e) => setSelectedPondId(e.target.value)}
            className="px-3 py-2 border border-slate-300 rounded-lg text-sm"
          >
            {pondOptions.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Hàng trên: mẫu loài cá + ngưỡng chung cho ao */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
        {/* Một số loài cá tiêu biểu & ngưỡng khuyến nghị */}
        {fishSamples.length > 0 && (
          <div className="bg-white rounded-xl shadow-sm border border-slate-100 p-4">
            <h3 className="text-sm font-semibold text-slate-700 mb-2">
              Một số loài cá tiêu biểu & ngưỡng khuyến nghị
            </h3>
            <p className="text-xs text-slate-500 mb-3">
              Dùng để tham khảo nhanh khi cấu hình ngưỡng cho ao. Các giá trị dưới đây chỉ là gợi ý,
              bạn có thể điều chỉnh tuỳ điều kiện thực tế.
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {fishSamples.map((f) => (
                <div
                  key={f.id}
                  className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-xs"
                >
                  <div className="font-semibold text-slate-800 truncate">
                    {f.nameVietnamese && f.nameVietnamese !== "0"
                      ? f.nameVietnamese
                      : f.nameEnglish}
                  </div>
                  {f.nameEnglish && (
                    <div className="text-[11px] text-slate-500 italic truncate">
                      {f.nameEnglish}
                    </div>
                  )}
                  {f.taxonomy && (
                    <div className="mt-0.5 text-[10px] text-slate-400 truncate">
                      {f.taxonomy}
                    </div>
                  )}
                  <div className="mt-1 space-y-0.5">
                    {f.tempRange && (
                      <div className="flex items-center gap-1 text-[11px] text-slate-600">
                        <span>🌡️</span>
                        <span>{f.tempRange}</span>
                      </div>
                    )}
                    {f.phRange && (
                      <div className="flex items-center gap-1 text-[11px] text-slate-600">
                        <span>📊</span>
                        <span>{f.phRange}</span>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Ngưỡng chung cho ao */}
        <div className="bg-white rounded-xl shadow p-6">
          <h3 className="text-sm font-medium text-slate-700 mb-4">
            Ngưỡng chung cho ao
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">
                Mực nước thấp (%)
              </label>
              <input
                type="number"
                value={form.waterLow}
                onChange={(e) =>
                  setForm({ ...form, waterLow: Number(e.target.value) })
                }
                className="w-full p-2 border rounded"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">
                Mực nước cao (%)
              </label>
              <input
                type="number"
                value={form.waterHigh}
                onChange={(e) =>
                  setForm({ ...form, waterHigh: Number(e.target.value) })
                }
                className="w-full p-2 border rounded"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">
                pH thấp
              </label>
              <input
                type="number"
                step="0.1"
                value={form.phLow}
                onChange={(e) =>
                  setForm({ ...form, phLow: Number(e.target.value) })
                }
                className="w-full p-2 border rounded"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">
                pH cao
              </label>
              <input
                type="number"
                step="0.1"
                value={form.phHigh}
                onChange={(e) =>
                  setForm({ ...form, phHigh: Number(e.target.value) })
                }
                className="w-full p-2 border rounded"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">
                Nhiệt độ thấp (°C)
              </label>
              <input
                type="number"
                value={form.tempLow}
                onChange={(e) =>
                  setForm({ ...form, tempLow: Number(e.target.value) })
                }
                className="w-full p-2 border rounded"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">
                Nhiệt độ cao (°C)
              </label>
              <input
                type="number"
                value={form.tempHigh}
                onChange={(e) =>
                  setForm({ ...form, tempHigh: Number(e.target.value) })
                }
                className="w-full p-2 border rounded"
              />
            </div>
          </div>
          <div className="mt-4 flex justify-end">
            <button
              onClick={handleSave}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-medium"
            >
              💾 Lưu ngưỡng cho ao
            </button>
          </div>
        </div>
      </div>

      {/* Ngưỡng theo từng loài cá – full-width phía dưới */}
      <div className="bg-white rounded-xl shadow p-6 w-full flex-1">
        <h3 className="text-sm font-medium text-slate-700 mb-3">
          Ngưỡng theo từng loài cá
        </h3>
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-3">
          <p className="text-xs text-slate-500 max-w-xl">
            Chỉ hiển thị các loài cá đã có dữ liệu nhiệt độ / pH từ dataset hoặc cấu hình thủ công.
            Bạn có thể tìm nhanh theo tên và tinh chỉnh lại ngưỡng cho từng loài.
          </p>
          <div className="flex items-center gap-2">
            <input
              type="text"
              value={searchName}
              onChange={(e) => setSearchName(e.target.value)}
              placeholder="Tìm theo tên EN / VN..."
              className="px-3 py-1.5 border border-slate-300 rounded-lg text-xs w-48"
            />
            <button
              type="button"
              onClick={() => fetchFishList(0, searchName)}
              className="px-3 py-1.5 rounded-lg border border-slate-300 text-xs text-slate-700 hover:bg-slate-50"
            >
              Lọc
            </button>
          </div>
        </div>
        <div className="border border-slate-200 rounded-lg overflow-hidden text-xs h-full w-full">
          <div className="bg-slate-50 px-3 py-2 flex justify-between items-center">
            <span className="text-[11px]">
              Trang {page + 1}/{Math.max(totalPages, 1)}
            </span>
            <div className="space-x-2">
              <button
                type="button"
                disabled={page === 0}
                onClick={() => fetchFishList(Math.max(page - 1, 0), searchName)}
                className={`px-2 py-1 rounded border ${
                  page === 0
                    ? "bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed"
                    : "bg-white text-slate-700 border-slate-300 hover:bg-slate-50"
                }`}
              >
                ◀
              </button>
              <button
                type="button"
                disabled={totalPages === 0 || page >= totalPages - 1}
                onClick={() =>
                  fetchFishList(
                    totalPages === 0 ? page : Math.min(page + 1, totalPages - 1),
                    searchName
                  )
                }
                className={`px-2 py-1 rounded border ${
                  totalPages === 0 || page >= totalPages - 1
                    ? "bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed"
                    : "bg-white text-slate-700 border-slate-300 hover:bg-slate-50"
                }`}
              >
                ▶
              </button>
            </div>
          </div>
          {/* Header cột */}
          <div className="hidden md:grid grid-cols-[12rem,10rem,repeat(4,minmax(0,1fr)),5.5rem] gap-2 px-3 py-2 border-t border-slate-100 bg-slate-50 text-[11px] font-semibold text-slate-600">
            <div>Tên loài</div>
            <div>Nhiệt độ / pH (dataset)</div>
            <div className="text-center">Temp min (°C)</div>
            <div className="text-center">Temp max (°C)</div>
            <div className="text-center">pH min</div>
            <div className="text-center">pH max</div>
            <div className="text-center">Hành động</div>
          </div>
          <div className="divide-y divide-slate-100">
            {fishLoading && (
              <div className="py-4 text-center text-slate-400">
                Đang tải danh sách loài cá...
              </div>
            )}
            {!fishLoading && fishList.length === 0 && (
              <div className="py-4 text-center text-slate-400">
                Không có loài cá nào.
              </div>
            )}
            {!fishLoading &&
              fishList.length > 0 &&
              fishList.map((f) => <FishThresholdRow key={f.id} fish={f} />)}
          </div>
        </div>
      </div>
    </div>
  );
}

function FishThresholdRow({ fish }) {
  // Parse default ranges, ưu tiên:
  // 1) custom*, 2) auto*, 3) parse từ chuỗi range (Celsius / pH)

  function normalizeDashes(str) {
    if (!str) return "";
    return str.replace(/[\u2010-\u2015\u2212]/g, "-");
  }

  const parseTempRange = () => {
    if (fish.customTempMin != null || fish.customTempMax != null) {
      return [fish.customTempMin ?? "", fish.customTempMax ?? ""];
    }
    if (fish.autoTempMin != null || fish.autoTempMax != null) {
      return [fish.autoTempMin ?? "", fish.autoTempMax ?? ""];
    }
    if (!fish.tempRange) return ["", ""];

    let source = fish.tempRange;

    // Ví dụ: "72–79 °F (22–26 °C)" -> ưu tiên phần °C nếu có
    const matchC = source.match(/\(([^)]*?)(?:°\s*C|C)\)/i);
    if (matchC) {
      source = matchC[1];
    }

    source = normalizeDashes(source);

    // Loại bỏ phần sau "[" hoặc "(" để tránh chú thích như [39], (Ref...)
    source = source.split("[")[0].split("(")[0];

    const parts = source
      .split("-")
      .map((p) => p.trim())
      .filter((p) => p.length > 0);

    if (parts.length >= 2) {
      const a = parseFloat(parts[0].replace(",", "."));
      const b = parseFloat(parts[1].replace(",", "."));
      if (!Number.isNaN(a) && !Number.isNaN(b)) {
        // Nếu cả hai giá trị nhỏ hơn hoặc bằng 14 và không có "°C" trong chuỗi gốc
        // thì khả năng cao đây là khoảng pH bị đặt nhầm vào cột nhiệt độ -> bỏ qua.
        const originalHasC =
          /°\s*C|Celsius|độ\s*C/i.test(fish.tempRange ?? "") || /°C/i.test(fish.tempRange ?? "");
        if (!originalHasC && a <= 14 && b <= 14) {
          return ["", ""];
        }
        const min = Math.min(a, b);
        const max = Math.max(a, b);
        return [min, max];
      }
    }

    return ["", ""];
  };

  const parsePhRange = () => {
    if (fish.customPhMin != null || fish.customPhMax != null) {
      return [fish.customPhMin ?? "", fish.customPhMax ?? ""];
    }
    if (fish.autoPhMin != null || fish.autoPhMax != null) {
      return [fish.autoPhMin ?? "", fish.autoPhMax ?? ""];
    }
    if (!fish.phRange) return ["", ""];

    let source = normalizeDashes(fish.phRange);
    // Loại bỏ chú thích như [39], (Ref...)
    source = source.split("[")[0].split("(")[0];

    const parts = source
      .split("-")
      .map((p) => p.trim())
      .filter((p) => p.length > 0);

    if (parts.length >= 2) {
      const a = parseFloat(parts[0].replace(",", "."));
      const b = parseFloat(parts[1].replace(",", "."));
      if (!Number.isNaN(a) && !Number.isNaN(b)) {
        const min = Math.min(a, b);
        const max = Math.max(a, b);
        return [min, max];
      }
    }

    return ["", ""];
  };

  const [initTempMin, initTempMax] = parseTempRange();
  const [initPhMin, initPhMax] = parsePhRange();

  const [tempMin, setTempMin] = useState(initTempMin);
  const [tempMax, setTempMax] = useState(initTempMax);
  const [phMin, setPhMin] = useState(initPhMin);
  const [phMax, setPhMax] = useState(initPhMax);
  const [saving, setSaving] = useState(false);

  async function saveRow() {
    setSaving(true);
    try {
      const body = {
        tempMin: tempMin === "" ? null : parseFloat(tempMin),
        tempMax: tempMax === "" ? null : parseFloat(tempMax),
        phMin: phMin === "" ? null : parseFloat(phMin),
        phMax: phMax === "" ? null : parseFloat(phMax),
      };
      await fetch(`${API_BASE}/api/fish/${fish.id}/thresholds`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch (e) {
      console.error("Failed to save thresholds for row", e);
    } finally {
      setSaving(false);
    }
  }

  async function resetRow() {
    setSaving(true);
    try {
      await fetch(`${API_BASE}/api/fish/${fish.id}/reset`, {
        method: "POST",
      });
      setTempMin("");
      setTempMax("");
      setPhMin("");
      setPhMax("");
    } catch (e) {
      console.error("Failed to reset thresholds for row", e);
    } finally {
      setSaving(false);
    }
  }

  const hasCustom =
    tempMin !== "" || tempMax !== "" || phMin !== "" || phMax !== "";

  return (
    <div className="px-3 py-3 flex items-start gap-3 text-xs">
      <div className="w-48">
        <div className="font-medium text-slate-800 truncate">
          {fish.nameVietnamese && fish.nameVietnamese !== "0"
            ? fish.nameVietnamese
            : fish.nameEnglish}
        </div>
        {fish.taxonomy && (
          <div className="text-[10px] text-slate-400 truncate">{fish.taxonomy}</div>
        )}
      </div>
      <div className="w-40 text-[10px] text-slate-500 space-y-1">
        {fish.tempRange && (
          <div className="flex items-center gap-1">
            <span>🌡️</span>
            <span className="truncate">{fish.tempRange}</span>
          </div>
        )}
        {fish.phRange && (
          <div className="flex items-center gap-1">
            <span>📊</span>
            <span className="truncate">{fish.phRange}</span>
          </div>
        )}
      </div>
      <div className="flex-1 grid grid-cols-4 gap-2">
        <div className="flex flex-col gap-1">
          <span className="text-[10px] text-slate-400">Temp min (°C)</span>
          <input
            type="number"
            step="0.1"
            value={tempMin}
            onChange={(e) => setTempMin(e.target.value)}
            placeholder="VD: 22"
            className="w-full px-2 py-1 border border-slate-200 rounded"
          />
        </div>
        <div className="flex flex-col gap-1">
          <span className="text-[10px] text-slate-400">Temp max (°C)</span>
          <input
            type="number"
            step="0.1"
            value={tempMax}
            onChange={(e) => setTempMax(e.target.value)}
            placeholder="VD: 26"
            className="w-full px-2 py-1 border border-slate-200 rounded"
          />
        </div>
        <div className="flex flex-col gap-1">
          <span className="text-[10px] text-slate-400">pH min</span>
          <input
            type="number"
            step="0.1"
            value={phMin}
            onChange={(e) => setPhMin(e.target.value)}
            placeholder="VD: 6.0"
            className="w-full px-2 py-1 border border-slate-200 rounded"
          />
        </div>
        <div className="flex flex-col gap-1">
          <span className="text-[10px] text-slate-400">pH max</span>
          <input
            type="number"
            step="0.1"
            value={phMax}
            onChange={(e) => setPhMax(e.target.value)}
            placeholder="VD: 7.0"
            className="w-full px-2 py-1 border border-slate-200 rounded"
          />
        </div>
      </div>
      <div className="flex items-center gap-1">
        <button
          type="button"
          disabled={saving}
          onClick={saveRow}
          className="px-2 py-1 rounded bg-blue-500 text-white disabled:bg-slate-300"
        >
          Lưu
        </button>
        <button
          type="button"
          disabled={saving || !hasCustom}
          onClick={resetRow}
          className="px-2 py-1 rounded border border-slate-300 text-slate-600 disabled:text-slate-300 disabled:border-slate-200"
        >
          Reset
        </button>
      </div>
    </div>
  );
}