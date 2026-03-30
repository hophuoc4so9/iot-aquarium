import React, { useState, useEffect } from "react";

const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

/**
 * Fish Species Manager Component
 * Quản lý các loài cá với ngưỡng cảnh báo tùy chỉnh
 */
export default function FishSpeciesManager() {
  const [fishList, setFishList] = useState([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [loading, setLoading] = useState(false);
  const [showOnlyCustom, setShowOnlyCustom] = useState(false);
  const [page, setPage] = useState(0);
  const [pageSize] = useState(30);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const [selectedFish, setSelectedFish] = useState(null);
  const [showEditModal, setShowEditModal] = useState(false);
  const [toast, setToast] = useState({ show: false, message: "", type: "info" });
  const [defaults, setDefaults] = useState({});
  const [showCreateModal, setShowCreateModal] = useState(false);

  // Fetch default thresholds
  useEffect(() => {
    fetchDefaults();
  }, []);

  // Reset về trang 0 mỗi khi đổi từ khóa tìm kiếm
  useEffect(() => {
    setPage(0);
  }, [searchTerm]);

  // Fetch fish list on mount and when search/page changes
  useEffect(() => {
    fetchFishList();
  }, [searchTerm, page]);

  async function fetchDefaults() {
    try {
      const res = await fetch(`${API_BASE}/api/fish/defaults`);
      if (res.ok) {
        const data = await res.json();
        setDefaults(data);
      }
    } catch (error) {
      console.error("Failed to fetch defaults:", error);
    }
  }

  async function fetchFishList() {
    setLoading(true);
    try {
      // Khi không tìm kiếm, chỉ lấy các loài đã có ngưỡng / dải temp/pH (có phân trang)
      const url = searchTerm
        ? `${API_BASE}/api/fish/search?name=${encodeURIComponent(searchTerm)}`
        : `${API_BASE}/api/fish/configured?page=${page}&size=${pageSize}`;

      const res = await fetch(url);
      if (res.ok) {
        const data = await res.json();
        if (searchTerm) {
          // search trả về List<FishSpecies>
          setFishList(data);
          setTotalElements(data.length);
          setTotalPages(1);
        } else {
          // configured trả về Page<FishSpecies>
          setFishList(data.content ?? []);
          setTotalElements(data.totalElements ?? (data.content?.length ?? 0));
          setTotalPages(data.totalPages ?? 0);
        }
      }
    } catch (error) {
      console.error("Failed to fetch fish list:", error);
      showToast("Lỗi khi tải danh sách cá", "error");
    } finally {
      setLoading(false);
    }
  }

  async function fetchFishDetails(fishId) {
    try {
      const res = await fetch(`${API_BASE}/api/fish/${fishId}`);
      if (res.ok) {
        const data = await res.json();
        setSelectedFish(data);
        setShowEditModal(true);
      }
    } catch (error) {
      console.error("Failed to fetch fish details:", error);
      showToast("Lỗi khi tải thông tin cá", "error");
    }
  }

  async function updateThresholds(fishId, thresholds) {
    try {
      const res = await fetch(`${API_BASE}/api/fish/${fishId}/thresholds`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(thresholds),
      });
      
      if (res.ok) {
        showToast("Cập nhật ngưỡng cảnh báo thành công!", "success");
        fetchFishList();
        setShowEditModal(false);
      } else {
        showToast("Lỗi khi cập nhật ngưỡng cảnh báo", "error");
      }
    } catch (error) {
      console.error("Failed to update thresholds:", error);
      showToast("Lỗi khi cập nhật ngưỡng cảnh báo", "error");
    }
  }

  async function resetThresholds(fishId) {
    try {
      const res = await fetch(`${API_BASE}/api/fish/${fishId}/reset`, {
        method: "POST",
      });
      
      if (res.ok) {
        showToast("Đã reset về giá trị mặc định!", "success");
        fetchFishList();
        setShowEditModal(false);
      } else {
        showToast("Lỗi khi reset ngưỡng cảnh báo", "error");
      }
    } catch (error) {
      console.error("Failed to reset thresholds:", error);
      showToast("Lỗi khi reset ngưỡng cảnh báo", "error");
    }
  }

  function showToast(message, type = "info") {
    setToast({ show: true, message, type });
    setTimeout(() => setToast({ show: false, message: "", type: "info" }), 4000);
  }

  return (
    <div className="bg-white rounded-xl shadow p-6">
      <div className="mb-6 flex flex-col md:flex-row md:items-end md:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold text-slate-800 mb-2">
            🐠 Quản lý loài cá & ngưỡng
          </h2>
          <p className="text-sm text-slate-500">
            Tìm kiếm và cấu hình ngưỡng cảnh báo riêng cho từng loài cá.
            Các loài đã được đặt ngưỡng sẽ có nhãn "Có ngưỡng tùy chỉnh".
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setShowCreateModal(true)}
            className="px-3 py-2 rounded-lg text-xs font-medium bg-emerald-600 text-white hover:bg-emerald-700"
          >
            + Thêm loài cá
          </button>
          <button
            type="button"
            onClick={() => setShowOnlyCustom((v) => !v)}
            className={`px-3 py-2 rounded-lg text-xs font-medium border transition ${
              showOnlyCustom
                ? "bg-blue-600 text-white border-blue-600"
                : "bg-white text-slate-700 border-slate-300 hover:bg-slate-50"
            }`}
          >
            {showOnlyCustom ? "Hiện tất cả loài" : "Chỉ hiện loài có ngưỡng tùy chỉnh"}
          </button>
        </div>
      </div>

      {/* Search Bar */}
      <div className="mb-6">
        <div className="relative">
          <input
            type="text"
            placeholder="Tìm theo tên tiếng Anh hoặc tiếng Việt..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full px-4 py-3 pl-11 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
          <svg
            className="absolute left-3 top-3.5 h-5 w-5 text-slate-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
        </div>
      </div>

      {/* Default Thresholds Info */}
      {defaults.tempMin && (
        <div className="mb-6 p-4 bg-blue-50 rounded-lg border border-blue-200">
          <div className="text-sm font-medium text-blue-800 mb-2">
            📊 Ngưỡng mặc định của hệ thống:
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
            <div>
              <span className="text-blue-600">Nhiệt độ thấp:</span>{" "}
              <span className="font-bold">{defaults.tempMin}°C</span>
            </div>
            <div>
              <span className="text-blue-600">Nhiệt độ cao:</span>{" "}
              <span className="font-bold">{defaults.tempMax}°C</span>
            </div>
            <div>
              <span className="text-blue-600">pH thấp:</span>{" "}
              <span className="font-bold">{defaults.phMin}</span>
            </div>
            <div>
              <span className="text-blue-600">pH cao:</span>{" "}
              <span className="font-bold">{defaults.phMax}</span>
            </div>
          </div>
        </div>
      )}

      {/* Loading State */}
      {loading && (
        <div className="text-center py-12">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p className="mt-2 text-sm text-slate-500">Đang tải...</p>
        </div>
      )}

      {/* Fish List */}
      {!loading && fishList.length === 0 && (
        <div className="text-center py-12 text-slate-500">
          <svg
            className="mx-auto h-12 w-12 text-slate-300"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <p className="mt-2">Không tìm thấy loài cá nào</p>
        </div>
      )}

      {!loading && fishList.length > 0 && (
        <>
          <div className="flex justify-between items-center mb-2 text-xs text-slate-400">
            <span>
              Trang {page + 1}/{Math.max(totalPages, 1)} – Tổng {totalElements} loài
            </span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-4">
            {fishList
              .filter((fish) => {
                if (!showOnlyCustom) return true;
                return (
                  fish.customTempMin != null ||
                  fish.customTempMax != null ||
                  fish.customPhMin != null ||
                  fish.customPhMax != null
                );
              })
              .map((fish) => (
                <FishCard
                  key={fish.id}
                  fish={fish}
                  onSelect={() => fetchFishDetails(fish.id)}
                />
              ))}
          </div>
          <div className="flex justify-between items-center mt-1 text-xs text-slate-600">
            <button
              type="button"
              disabled={page === 0}
              onClick={() => setPage((p) => Math.max(p - 1, 0))}
              className={`px-3 py-1 rounded-lg border ${
                page === 0
                  ? "bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed"
                  : "bg-white text-slate-700 border-slate-300 hover:bg-slate-50"
              }`}
            >
              ◀ Trang trước
            </button>
            <button
              type="button"
              disabled={totalPages === 0 || page >= totalPages - 1}
              onClick={() =>
                setPage((p) =>
                  totalPages === 0 ? p : Math.min(p + 1, totalPages - 1)
                )
              }
              className={`px-3 py-1 rounded-lg border ${
                totalPages === 0 || page >= totalPages - 1
                  ? "bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed"
                  : "bg-white text-slate-700 border-slate-300 hover:bg-slate-50"
              }`}
            >
              Trang sau ▶
            </button>
          </div>
        </>
      )}

      {/* Edit Modal */}
      {showEditModal && selectedFish && (
        <EditThresholdsModal
          fish={selectedFish}
          defaults={defaults}
          onClose={() => setShowEditModal(false)}
          onSave={(thresholds) => updateThresholds(selectedFish.fish.id, thresholds)}
          onReset={() => resetThresholds(selectedFish.fish.id)}
        />
      )}

      {/* Create Fish Modal */}
      {showCreateModal && (
        <CreateFishModal
          onClose={() => setShowCreateModal(false)}
          onCreated={() => {
            setShowCreateModal(false);
            fetchFishList();
          }}
          showToast={showToast}
        />
      )}

      {/* Toast Notification */}
      {toast.show && (
        <Toast message={toast.message} type={toast.type} />
      )}
    </div>
  );
}

function FishCard({ fish, onSelect }) {
  const hasCustomThresholds =
    fish.customTempMin !== null ||
    fish.customTempMax !== null ||
    fish.customPhMin !== null ||
    fish.customPhMax !== null;

  const displayNameVi =
    fish.nameVietnamese && fish.nameVietnamese !== "0"
      ? fish.nameVietnamese
      : null;

  return (
    <div
      onClick={onSelect}
      className="bg-white border border-slate-200 rounded-xl p-4 hover:shadow-lg hover:border-blue-400 transition cursor-pointer flex flex-col"
    >
      {/* Ảnh */}
      {fish.imageUrl && (
        <div className="w-full h-32 mb-3 rounded-lg overflow-hidden bg-slate-100">
          <img
            src={fish.imageUrl}
            alt={fish.nameEnglish}
            className="w-full h-full object-cover"
            onError={(e) => {
              e.target.style.display = "none";
            }}
          />
        </div>
      )}

      {/* Tên */}
      <div className="mb-2">
        <h3 className="font-semibold text-slate-900 text-sm truncate">
          {fish.nameEnglish}
        </h3>
        {displayNameVi && (
          <p className="text-xs text-emerald-700 mt-0.5 truncate">
            {displayNameVi}
          </p>
        )}
        {fish.taxonomy && (
          <p className="text-[11px] text-slate-400 italic mt-0.5 truncate">
            {fish.taxonomy}
          </p>
        )}
      </div>

      {/* Thông số chính */}
      <div className="text-xs text-slate-600 space-y-1 mb-3 flex-1">
        {fish.tempRange && (
          <div className="flex items-center">
            <span className="mr-1">🌡️</span>
            <span className="truncate">{fish.tempRange}</span>
          </div>
        )}
        {fish.phRange && (
          <div className="flex items-center">
            <span className="mr-1">📊</span>
            <span className="truncate">pH: {fish.phRange}</span>
          </div>
        )}
        {fish.vnStatus && (
          <div className="flex items-center">
            <span className="mr-1">🇻🇳</span>
            <span className="truncate">
              Trạng thái: {fish.vnStatus.toLowerCase()}
            </span>
          </div>
        )}
      </div>

      {/* Badge + hiện diện */}
      <div className="flex items-center justify-between">
        {hasCustomThresholds && (
          <span className="inline-flex items-center px-2 py-1 bg-blue-50 text-blue-700 text-[11px] rounded-full">
            <svg
              className="w-3 h-3 mr-1"
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
            </svg>
            Có ngưỡng tùy chỉnh
          </span>
        )}
        {fish.vnCurrentPresence && (
          <span className="text-[11px] text-slate-400">
            {fish.vnCurrentPresence}
          </span>
        )}
      </div>
    </div>
  );
}

function EditThresholdsModal({ fish, defaults, onClose, onSave, onReset }) {
  const [nameEnglish, setNameEnglish] = useState(fish.fish.nameEnglish || "");
  const [nameVietnamese, setNameVietnamese] = useState(
    fish.fish.nameVietnamese && fish.fish.nameVietnamese !== "0"
      ? fish.fish.nameVietnamese
      : ""
  );
  const [remarksEn, setRemarksEn] = useState(fish.fish.remarksEn || "");
  const [remarksVi, setRemarksVi] = useState(fish.fish.remarksVi || "");

  const [tempMin, setTempMin] = useState(
    fish.fish.customTempMin ?? defaults.tempMin ?? ""
  );
  const [tempMax, setTempMax] = useState(
    fish.fish.customTempMax ?? defaults.tempMax ?? ""
  );
  const [phMin, setPhMin] = useState(
    fish.fish.customPhMin ?? defaults.phMin ?? ""
  );
  const [phMax, setPhMax] = useState(
    fish.fish.customPhMax ?? defaults.phMax ?? ""
  );

  function handleSave() {
    const thresholds = {
      tempMin: tempMin ? parseFloat(tempMin) : null,
      tempMax: tempMax ? parseFloat(tempMax) : null,
      phMin: phMin ? parseFloat(phMin) : null,
      phMax: phMax ? parseFloat(phMax) : null,
    };
    onSave(thresholds);
  }

  async function handleSaveWiki() {
    try {
      const body = {
        nameEnglish,
        nameVietnamese,
        remarksEn,
        remarksVi,
        tempRange: fish.fish.tempRange,
        phRange: fish.fish.phRange,
        imageUrl: fish.fish.imageUrl,
        taxonomy: fish.fish.taxonomy,
      };
      const res = await fetch(
        `${API_BASE}/api/admin/fish/${fish.fish.id}/wiki`,
        {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        }
      );
      if (!res.ok) {
        console.error("Failed to save wiki info");
        alert("Lưu thông tin loài cá thất bại");
      } else {
        alert("Lưu thông tin loài cá thành công");
      }
    } catch (e) {
      console.error("Failed to save wiki info", e);
      alert("Lưu thông tin loài cá thất bại");
    }
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="p-6 border-b border-slate-200">
          <div className="flex justify-between items-start">
            <div>
              <h3 className="text-xl font-semibold text-slate-800">
                {nameEnglish}
              </h3>
              {nameVietnamese && (
                <p className="text-sm text-slate-500 mt-1">
                  {nameVietnamese}
                </p>
              )}
            </div>
            <button
              onClick={onClose}
              className="text-slate-400 hover:text-slate-600"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        {/* Image */}
        {fish.fish.imageUrl && (
          <div className="p-6">
            <img
              src={fish.fish.imageUrl}
              alt={fish.fish.nameEnglish}
              className="w-full h-48 object-cover rounded-lg"
              onError={(e) => {
                e.target.style.display = "none";
              }}
            />
          </div>
        )}

        {/* Info */}
        <div className="px-6 pb-5 space-y-6">
          {/* 1. Wiki editor */}
          <div>
            <h4 className="text-sm font-semibold text-slate-800 mb-3">
              Thông tin loài cá (wiki)
            </h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              <div>
                <label className="block text-xs text-slate-600 mb-1">
                  Tên tiếng Anh
                </label>
                <input
                  type="text"
                  value={nameEnglish}
                  onChange={(e) => setNameEnglish(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-600 mb-1">
                  Tên tiếng Việt
                </label>
                <input
                  type="text"
                  value={nameVietnamese}
                  onChange={(e) => setNameVietnamese(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
                />
              </div>
            </div>

            <div className="mb-2 flex justify-between items-center">
              <span className="text-xs font-medium text-slate-600">
                Mô tả tiếng Anh
              </span>
            </div>
            <textarea
              value={remarksEn}
              onChange={(e) => setRemarksEn(e.target.value)}
              rows={3}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm mb-4"
            />

            <div className="mb-2 flex justify-between items-center">
              <span className="text-xs font-medium text-slate-600">
                Mô tả tiếng Việt
              </span>
              <button
                type="button"
                onClick={() => setRemarksVi(remarksEn)}
                className="text-xs px-2 py-1 border border-slate-300 rounded-lg hover:bg-slate-50"
              >
                Sao chép từ tiếng Anh
              </button>
            </div>
            <textarea
              value={remarksVi}
              onChange={(e) => setRemarksVi(e.target.value)}
              rows={3}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
            />

            <div className="mt-3 flex justify-end">
              <button
                type="button"
                onClick={handleSaveWiki}
                className="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 text-sm"
              >
                💾 Lưu thông tin loài cá
              </button>
            </div>
          </div>

          {/* 2. Thông số môi trường / phân bố */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            {/* Phạm vi nước */}
            <div className="space-y-2">
              {fish.fish.tempRange && (
                <div>
                  <span className="text-slate-500 text-xs">
                    Nhiệt độ phù hợp
                  </span>
                  <p className="font-medium text-slate-800">
                    {fish.fish.tempRange}
                  </p>
                </div>
              )}
              {fish.fish.phRange && (
                <div>
                  <span className="text-slate-500 text-xs">pH phù hợp</span>
                  <p className="font-medium text-slate-800">
                    {fish.fish.phRange}
                  </p>
                </div>
              )}
              {(fish.fish.autoTempMin != null ||
                fish.fish.autoTempMax != null) && (
                <div>
                  <span className="text-slate-500 text-xs">
                    Nhiệt độ gợi ý (số)
                  </span>
                  <p className="font-medium text-slate-800">
                    {fish.fish.autoTempMin ?? "?"} –{" "}
                    {fish.fish.autoTempMax ?? "?"} °C
                  </p>
                </div>
              )}
              {(fish.fish.autoPhMin != null || fish.fish.autoPhMax != null) && (
                <div>
                  <span className="text-slate-500 text-xs">
                    pH gợi ý (số)
                  </span>
                  <p className="font-medium text-slate-800">
                    {fish.fish.autoPhMin ?? "?"} –{" "}
                    {fish.fish.autoPhMax ?? "?"}
                  </p>
                </div>
              )}
            </div>

            {/* Phân bố Việt Nam */}
            <div className="space-y-2">
              <div>
                <span className="text-slate-500 text-xs">
                  Tình trạng tại Việt Nam
                </span>
                <p className="font-medium text-slate-800">
                  {fish.fish.vnStatus || "Không rõ"}
                </p>
              </div>
              <div>
                <span className="text-slate-500 text-xs">Hiện diện</span>
                <p className="font-medium text-slate-800">
                  {fish.fish.vnCurrentPresence || "Không rõ"}
                </p>
              </div>
              <div className="flex flex-wrap gap-1 text-xs">
                {fish.fish.vnFreshwater && (
                  <span className="px-2 py-0.5 rounded-full bg-sky-50 text-sky-700">
                    Nước ngọt
                  </span>
                )}
                {fish.fish.vnBrackish && (
                  <span className="px-2 py-0.5 rounded-full bg-amber-50 text-amber-700">
                    Nước lợ
                  </span>
                )}
                {fish.fish.vnSaltwater && (
                  <span className="px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700">
                    Nước mặn
                  </span>
                )}
              </div>
              {fish.fish.vnDistributionComments && (
                <div>
                  <span className="text-slate-500 text-xs">
                    Ghi chú phân bố
                  </span>
                  <p className="text-xs text-slate-700 whitespace-pre-line">
                    {fish.fish.vnDistributionComments}
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Current Effective Thresholds */}
        <div className="px-6 pb-4">
          <div className="p-4 bg-slate-50 rounded-lg border border-slate-200">
            <div className="text-sm font-medium text-slate-700 mb-2">
              Ngưỡng cảnh báo hiện tại:
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
              <div>
                <span className="text-slate-500">Temp Min:</span>{" "}
                <span className="font-bold text-slate-800">
                  {fish.effectiveThresholds.tempMin}°C
                </span>
              </div>
              <div>
                <span className="text-slate-500">Temp Max:</span>{" "}
                <span className="font-bold text-slate-800">
                  {fish.effectiveThresholds.tempMax}°C
                </span>
              </div>
              <div>
                <span className="text-slate-500">pH Min:</span>{" "}
                <span className="font-bold text-slate-800">
                  {fish.effectiveThresholds.phMin}
                </span>
              </div>
              <div>
                <span className="text-slate-500">pH Max:</span>{" "}
                <span className="font-bold text-slate-800">
                  {fish.effectiveThresholds.phMax}
                </span>
              </div>
            </div>
            {fish.usingCustom && (
              <div className="mt-2 text-xs text-blue-600">
                ✓ Đang sử dụng ngưỡng tùy chỉnh
              </div>
            )}
            {!fish.usingCustom && (
              <div className="mt-2 text-xs text-slate-500">
                ⚙️ Đang sử dụng ngưỡng mặc định
              </div>
            )}
          </div>
        </div>

        {/* Edit Form */}
        <div className="px-6 pb-6">
          <h4 className="text-sm font-medium text-slate-700 mb-3">
            Cập nhật ngưỡng cảnh báo:
          </h4>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs text-slate-600 mb-1">
                Nhiệt độ tối thiểu (°C)
              </label>
              <input
                type="number"
                step="0.1"
                value={tempMin}
                onChange={(e) => setTempMin(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder={`Mặc định: ${defaults.tempMin}`}
              />
            </div>
            <div>
              <label className="block text-xs text-slate-600 mb-1">
                Nhiệt độ tối đa (°C)
              </label>
              <input
                type="number"
                step="0.1"
                value={tempMax}
                onChange={(e) => setTempMax(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder={`Mặc định: ${defaults.tempMax}`}
              />
            </div>
            <div>
              <label className="block text-xs text-slate-600 mb-1">
                pH tối thiểu
              </label>
              <input
                type="number"
                step="0.1"
                value={phMin}
                onChange={(e) => setPhMin(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder={`Mặc định: ${defaults.phMin}`}
              />
            </div>
            <div>
              <label className="block text-xs text-slate-600 mb-1">
                pH tối đa
              </label>
              <input
                type="number"
                step="0.1"
                value={phMax}
                onChange={(e) => setPhMax(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder={`Mặc định: ${defaults.phMax}`}
              />
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="px-6 pb-6 flex gap-3">
          <button
            onClick={handleSave}
            className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium"
          >
            💾 Lưu thay đổi
          </button>
          <button
            onClick={onReset}
            className="px-4 py-2 bg-slate-200 text-slate-700 rounded-lg hover:bg-slate-300 font-medium"
          >
            🔄 Reset mặc định
          </button>
          <button
            onClick={onClose}
            className="px-4 py-2 border border-slate-300 text-slate-700 rounded-lg hover:bg-slate-50 font-medium"
          >
            Hủy
          </button>
        </div>
      </div>
    </div>
  );
}

function CreateFishModal({ onClose, onCreated, showToast }) {
  const [nameEnglish, setNameEnglish] = useState("");
  const [nameVietnamese, setNameVietnamese] = useState("");
  const [taxonomy, setTaxonomy] = useState("");
  const [tempRange, setTempRange] = useState("");
  const [phRange, setPhRange] = useState("");

  async function handleCreate() {
    try {
      const body = {
        nameEnglish,
        nameVietnamese: nameVietnamese || null,
        taxonomy: taxonomy || null,
        tempRange: tempRange || null,
        phRange: phRange || null,
        isActive: true,
      };
      const res = await fetch(`${API_BASE}/api/fish`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        showToast("Tạo loài cá mới thất bại", "error");
        return;
      }
      showToast("Đã tạo loài cá mới", "success");
      onCreated();
    } catch (e) {
      console.error("Failed to create fish", e);
      showToast("Tạo loài cá mới thất bại", "error");
    }
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <div className="p-6 border-b border-slate-200 flex justify-between items-center">
          <h3 className="text-lg font-semibold text-slate-800">
            Thêm loài cá mới
          </h3>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <div className="p-6 space-y-3 text-sm">
          <div>
            <label className="block text-xs text-slate-600 mb-1">
              Tên tiếng Anh (bắt buộc)
            </label>
            <input
              type="text"
              value={nameEnglish}
              onChange={(e) => setNameEnglish(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label className="block text-xs text-slate-600 mb-1">
              Tên tiếng Việt
            </label>
            <input
              type="text"
              value={nameVietnamese}
              onChange={(e) => setNameVietnamese(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label className="block text-xs text-slate-600 mb-1">
              Tên khoa học (taxonomy)
            </label>
            <input
              type="text"
              value={taxonomy}
              onChange={(e) => setTaxonomy(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs text-slate-600 mb-1">
                Dải nhiệt độ mô tả (vd: 22–26 °C)
              </label>
              <input
                type="text"
                value={tempRange}
                onChange={(e) => setTempRange(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-xs text-slate-600 mb-1">
                Dải pH mô tả (vd: 6.5–7.5)
              </label>
              <input
                type="text"
                value={phRange}
                onChange={(e) => setPhRange(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>
        <div className="px-6 pb-6 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 border border-slate-300 text-slate-700 rounded-lg hover:bg-slate-50 text-sm"
          >
            Hủy
          </button>
          <button
            onClick={handleCreate}
            disabled={!nameEnglish.trim()}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              nameEnglish.trim()
                ? "bg-blue-600 text-white hover:bg-blue-700"
                : "bg-slate-200 text-slate-400 cursor-not-allowed"
            }`}
          >
            💾 Tạo loài cá
          </button>
        </div>
      </div>
    </div>
  );
}

function Toast({ message, type = "info" }) {
  const colors = {
    info: "bg-blue-600",
    success: "bg-green-600",
    error: "bg-red-600",
    warn: "bg-orange-600",
  };

  return (
    <div className="fixed bottom-4 right-4 z-50 animate-slide-up">
      <div
        className={`${colors[type]} text-white px-6 py-3 rounded-lg shadow-lg flex items-center gap-3`}
      >
        <span>{message}</span>
      </div>
    </div>
  );
}
