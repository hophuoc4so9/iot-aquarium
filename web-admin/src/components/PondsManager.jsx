import React, { useState, useEffect } from "react";
import HistoryChartsPage from "../pages/monitoring/HistoryChartsPage";

// Trỏ tới backend Java Spring Boot (mặc định 8080)
const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

// Khớp với model Pond bên Java (be/.../model/Pond.java)
const DEFAULT_POND = {
  id: "",
  name: "",
  area: "",
  fishType: "",
  stockingDate: "",
  density: "",
  note: "",
};

export default function PondsManager() {
  const [ponds, setPonds] = useState([]);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState(DEFAULT_POND);
  const [showForm, setShowForm] = useState(false);
  const [selectedPond, setSelectedPond] = useState(null);
  const [page, setPage] = useState(1);
  const pageSize = 5;
  const [total, setTotal] = useState(0);
  const [fishOptions, setFishOptions] = useState([]);
  const [fishLoading, setFishLoading] = useState(false);

  useEffect(() => {
    loadPonds();
  }, []);

  const loadPonds = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/ponds?page=${page - 1}&size=${pageSize}`);
      if (!res.ok) return;
      const data = await res.json();
      if (data && Array.isArray(data.content)) {
        setPonds(data.content);
        setTotal(typeof data.totalElements === "number" ? data.totalElements : data.content.length);
      } else if (Array.isArray(data)) {
        // fallback cho backend cũ không phân trang
        setPonds(data);
        setTotal(data.length);
      }
    } catch (e) {
      console.error("Failed to load ponds", e);
    }
  };

  const searchFish = async (name) => {
    if (!name || name.trim().length < 2) {
      setFishOptions([]);
      return;
    }
    setFishLoading(true);
    try {
      const params = new URLSearchParams({
        page: "0",
        size: "10",
        name: name.trim(),
      });
      const res = await fetch(`${API_BASE}/api/fish/configured?${params.toString()}`);
      if (!res.ok) {
        setFishOptions([]);
        return;
      }
      const data = await res.json();
      const list = Array.isArray(data) ? data : data.content ?? [];
      setFishOptions(list);
    } catch (e) {
      console.error("Failed to search fish for pond form", e);
      setFishOptions([]);
    } finally {
      setFishLoading(false);
    }
  };

  const openCreate = () => {
    setEditing(null);
    setForm(DEFAULT_POND);
    setShowForm(true);
  };

  const openEdit = (p) => {
    setEditing(p.id);
    setForm({ ...p });
    setShowForm(true);
  };

  const handleSave = async () => {
    const payload = {
      name: form.name,
      area: form.area,
      fishType: form.fishType,
      stockingDate: form.stockingDate,
      density: form.density,
      note: form.note,
    };

    try {
      if (editing) {
        await fetch(`${API_BASE}/api/ponds/${editing}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      } else {
        await fetch(`${API_BASE}/api/ponds`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      }
      await loadPonds();
      setShowForm(false);
      setForm(DEFAULT_POND);
      setEditing(null);
    } catch (e) {
      console.error("Failed to save pond", e);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Bạn có chắc muốn xóa ao này?")) return;
    try {
      await fetch(`${API_BASE}/api/ponds/${id}`, {
        method: "DELETE",
      });
      await loadPonds();
      if (editing === id) setShowForm(false);
      if (selectedPond?.id === id) setSelectedPond(null);
    } catch (e) {
      console.error("Failed to delete pond", e);
    }
  };

  const totalPages = Math.max(1, Math.ceil((total || ponds.length) / pageSize));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * pageSize;
  const pagedPonds = total ? ponds : ponds.slice(start, start + pageSize);

  const goToPage = (p) => {
    if (p < 1 || p > totalPages) return;
    setPage(p);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-xl font-semibold text-slate-800">Ao / Bể nuôi</h2>
          <p className="text-sm text-slate-500 mt-1">
            Danh sách toàn bộ ao đang được giám sát. Bấm vào từng ao để xem chi tiết cảm biến và lịch sử.
          </p>
        </div>
        <button
          onClick={openCreate}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 shadow-sm"
        >
          + Thêm ao
        </button>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-100 overflow-hidden">
        <table className="min-w-full divide-y divide-slate-200">
          <thead className="bg-slate-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wide">Tên ao</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wide">Diện tích (m²)</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wide">Loại cá</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wide">Ngày thả giống</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wide">Mật độ</th>
              <th className="px-4 py-3 text-right text-xs font-semibold text-slate-500 uppercase tracking-wide">Thao tác</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-200">
            {ponds.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-slate-500">
                  Chưa có ao nào. Bấm "Thêm ao" để tạo.
                </td>
              </tr>
            )}
            {pagedPonds.map((p) => (
              <tr key={p.id} className="hover:bg-slate-50 transition-colors">
                <td className="px-4 py-3 text-sm font-medium text-slate-800">
                  <div className="flex items-center gap-2">
                    <span>{p.name || "—"}</span>
                    {selectedPond?.id === p.id && (
                      <span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-medium bg-sky-50 text-sky-600 border border-sky-100">
                        Đang xem
                      </span>
                    )}
                  </div>
                </td>
                <td className="px-4 py-3 text-sm text-slate-600">{p.area || "—"}</td>
                <td className="px-4 py-3 text-sm text-slate-600">{p.fishType || "—"}</td>
                <td className="px-4 py-3 text-sm text-slate-600">{p.stockingDate || "—"}</td>
                <td className="px-4 py-3 text-sm text-slate-600">{p.density || "—"}</td>
                <td className="px-4 py-3 text-right">
                  <button
                    onClick={() => setSelectedPond(p)}
                    className="inline-flex items-center px-2 py-1 text-xs font-medium text-sky-700 bg-sky-50 rounded border border-sky-100 hover:bg-sky-100 mr-2"
                  >
                    Chi tiết
                  </button>
                  <button
                    onClick={() => openEdit(p)}
                    className="inline-flex items-center px-2 py-1 text-xs font-medium text-amber-700 bg-amber-50 rounded border border-amber-100 hover:bg-amber-100 mr-2"
                  >
                    Sửa
                  </button>
                  <button
                    onClick={() => handleDelete(p.id)}
                    className="inline-flex items-center px-2 py-1 text-xs font-medium text-rose-700 bg-rose-50 rounded border border-rose-100 hover:bg-rose-100"
                  >
                    Xóa
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {Math.max(total, ponds.length) > pageSize && (
        <div className="flex items-center justify-between text-sm text-slate-600">
          <div>
            Hiển thị{" "}
            <span className="font-medium">
              {start + 1}–{Math.min(start + pageSize, Math.max(total, ponds.length))}
            </span>{" "}
            trên <span className="font-medium">{Math.max(total, ponds.length)}</span> ao
          </div>
          <div className="inline-flex items-center gap-2">
            <button
              onClick={() => goToPage(currentPage - 1)}
              disabled={currentPage === 1}
              className="px-2 py-1 rounded border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
            >
              ← Trước
            </button>
            <span className="text-xs">
              Trang <span className="font-semibold">{currentPage}</span> / {totalPages}
            </span>
            <button
              onClick={() => goToPage(currentPage + 1)}
              disabled={currentPage === totalPages}
              className="px-2 py-1 rounded border border-slate-200 disabled:opacity-40 hover:bg-slate-50"
            >
              Sau →
            </button>
          </div>
        </div>
      )}

      {selectedPond && (
        <div className="bg-white rounded-xl shadow-sm border border-slate-100 p-6">
          <div className="flex items-start justify-between gap-4 mb-4">
            <div>
              <h3 className="text-lg font-semibold text-slate-800">
                Chi tiết ao: {selectedPond.name}
              </h3>
              <p className="text-sm text-slate-500">
                Thông tin cơ bản, biểu đồ và lịch sử môi trường cho ao này.
              </p>
            </div>
            <button
              onClick={() => setSelectedPond(null)}
              className="text-xs px-3 py-1 rounded-full border border-slate-200 text-slate-500 hover:text-slate-700 hover:bg-slate-50"
            >
              Đóng
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm mb-6">
            <div>
              <span className="font-medium text-slate-700">Diện tích:</span>{" "}
              <span className="text-slate-600">{selectedPond.area || "—"}</span>
            </div>
            <div>
              <span className="font-medium text-slate-700">Loại cá:</span>{" "}
              <span className="text-slate-600">{selectedPond.fishType || "—"}</span>
            </div>
            <div>
              <span className="font-medium text-slate-700">Ngày thả giống:</span>{" "}
              <span className="text-slate-600">{selectedPond.stockingDate || "—"}</span>
            </div>
            <div>
              <span className="font-medium text-slate-700">Mật độ:</span>{" "}
              <span className="text-slate-600">{selectedPond.density || "—"}</span>
            </div>
            <div className="md:col-span-2">
              <span className="font-medium text-slate-700">Ghi chú:</span>{" "}
              <span className="text-slate-600">{selectedPond.note || "—"}</span>
            </div>
          </div>

          <div className="border-t pt-4">
            <HistoryChartsPage pondId={selectedPond.id} />
          </div>
        </div>
      )}

      {showForm && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl shadow-lg p-6 w-full max-w-md">
            <h3 className="text-lg font-medium mb-4">{editing ? "Sửa ao" : "Thêm ao mới"}</h3>
            <div className="space-y-3">
              <div>
                <label className="block text-xs text-slate-500 mb-1">Tên ao *</label>
                <input
                  type="text"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  className="w-full p-2 border rounded"
                  placeholder="VD: Ao 1"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">Diện tích (m²)</label>
                <input
                  type="text"
                  value={form.area}
                  onChange={(e) => setForm({ ...form, area: e.target.value })}
                  className="w-full p-2 border rounded"
                  placeholder="VD: 500"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">
                  Loại cá đang nuôi{" "}
                  <span className="font-normal text-[10px] text-slate-400">
                    (chọn từ hệ thống hoặc tự nhập)
                  </span>
                </label>
                <input
                  type="text"
                  value={form.fishType}
                  onChange={(e) => {
                    const v = e.target.value;
                    setForm({ ...form, fishType: v });
                    searchFish(v);
                  }}
                  className="w-full p-2 border rounded"
                  placeholder="VD: Cá rô phi"
                />
                {fishLoading && (
                  <div className="mt-1 text-[11px] text-slate-400">
                    Đang tìm loài cá...
                  </div>
                )}
                {!fishLoading && fishOptions.length > 0 && (
                  <div className="mt-1 border border-slate-200 rounded-lg bg-white max-h-40 overflow-auto text-xs shadow-sm">
                    {fishOptions.map((f) => {
                      const vn =
                        f.nameVietnamese && f.nameVietnamese !== "0"
                          ? f.nameVietnamese
                          : null;
                      const en = f.nameEnglish;
                      const label = vn || en || "Loài cá không tên";
                      return (
                        <button
                          key={f.id}
                          type="button"
                          onClick={() => {
                            setForm({ ...form, fishType: label });
                            setFishOptions([]);
                          }}
                          className="w-full text-left px-2 py-1 hover:bg-slate-50 flex flex-col"
                        >
                          <span className="font-medium text-slate-800 truncate">
                            {label}
                          </span>
                          {(vn && en && vn !== en) && (
                            <span className="text-[10px] text-slate-400 truncate">
                              {en}
                            </span>
                          )}
                        </button>
                      );
                    })}
                  </div>
                )}
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">Ngày thả giống</label>
                <input
                  type="date"
                  value={form.stockingDate}
                  onChange={(e) => setForm({ ...form, stockingDate: e.target.value })}
                  className="w-full p-2 border rounded"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">Mật độ (con/m² hoặc mô tả)</label>
                <input
                  type="text"
                  value={form.density}
                  onChange={(e) => setForm({ ...form, density: e.target.value })}
                  className="w-full p-2 border rounded"
                  placeholder="VD: 3 con/m²"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">Ghi chú</label>
                <input
                  type="text"
                  value={form.note}
                  onChange={(e) => setForm({ ...form, note: e.target.value })}
                  className="w-full p-2 border rounded"
                />
              </div>
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button onClick={() => setShowForm(false)} className="px-3 py-2 rounded border">Hủy</button>
              <button onClick={handleSave} className="px-3 py-2 rounded bg-blue-600 text-white">Lưu</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
