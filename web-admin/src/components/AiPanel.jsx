import React, { useState } from "react";
import { appendDiagnosisLog } from "../lib/storage";

/**
 * AI Panel
 * - Gọi API dự báo (forecast) pH / nhiệt độ.
 * - Upload ảnh cá để kiểm tra dấu hiệu bệnh. Kết quả được ghi vào Nhật ký chẩn đoán.
 */
export default function AiPanel() {
  const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

  const [forecastMetric, setForecastMetric] = useState("PH");
  const [horizon, setHorizon] = useState(6);
  const [forecastLoading, setForecastLoading] = useState(false);
  const [forecastResult, setForecastResult] = useState(null);
  const [forecastError, setForecastError] = useState(null);

  const [file, setFile] = useState(null);
  const [imageLoading, setImageLoading] = useState(false);
  const [imageResult, setImageResult] = useState(null);
  const [imageError, setImageError] = useState(null);

  async function handleForecast() {
    setForecastLoading(true);
    setForecastError(null);
    setForecastResult(null);
    try {
      const params = new URLSearchParams({
        pondId: "1",
        metric: forecastMetric,
        horizonHours: String(horizon),
      });
      const res = await fetch(`${API_BASE}/api/ai/forecast?${params.toString()}`, {
        method: "POST",
      });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const data = await res.json();
      setForecastResult(data);
    } catch (e) {
      console.error("Forecast error", e);
      setForecastError(String(e));
    } finally {
      setForecastLoading(false);
    }
  }

  async function handleImageSubmit(e) {
    e.preventDefault();
    if (!file) return;
    setImageLoading(true);
    setImageError(null);
    setImageResult(null);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await fetch(`${API_BASE}/api/ai/fish-disease?pondId=1`, {
        method: "POST",
        body: formData,
      });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const data = await res.json();
      setImageResult(data);
      appendDiagnosisLog({
        label: data.label,
        score: data.score,
        fileName: file?.name,
        result: data.label,
      });
    } catch (e) {
      console.error("Fish disease error", e);
      setImageError(String(e));
    } finally {
      setImageLoading(false);
    }
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Forecast card */}
      <div className="bg-white rounded-xl shadow p-6">
        <h2 className="text-xl font-semibold text-slate-800 mb-2">
          🔮 Dự báo ngắn hạn
        </h2>
        <p className="text-sm text-slate-500 mb-4">
          Gọi AI service để dự báo pH hoặc nhiệt độ cho ao số 1 trong vài giờ tới.
        </p>

        <div className="flex flex-col md:flex-row gap-4 mb-4">
          <div className="flex-1">
            <label className="block text-xs font-medium text-slate-600 mb-1">
              Tham số
            </label>
            <select
              value={forecastMetric}
              onChange={(e) => setForecastMetric(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm"
            >
              <option value="PH">pH</option>
              <option value="TEMP">Nhiệt độ</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-600 mb-1">
              Horizon (giờ)
            </label>
            <select
              value={horizon}
              onChange={(e) => setHorizon(Number(e.target.value))}
              className="px-3 py-2 border border-slate-300 rounded-lg text-sm"
            >
              <option value={1}>1</option>
              <option value={3}>3</option>
              <option value={6}>6</option>
            </select>
          </div>
        </div>

        <button
          onClick={handleForecast}
          disabled={forecastLoading}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50"
        >
          {forecastLoading ? "Đang gọi AI..." : "Gọi AI forecast"}
        </button>

        <div className="mt-4">
          {forecastError && (
            <div className="text-sm text-red-600">
              Lỗi gọi forecast: {forecastError}
            </div>
          )}
          {forecastResult && Array.isArray(forecastResult.points) && (
            <div className="mt-3 text-sm">
              <div className="font-medium mb-1">Kết quả dự báo:</div>
              <ul className="space-y-1 max-h-48 overflow-auto text-xs">
                {forecastResult.points.map((p, idx) => (
                  <li key={idx} className="flex justify-between border-b border-slate-100 py-1">
                    <span className="text-slate-500">{p.timestamp}</span>
                    <span className="font-semibold text-slate-800">
                      {p.value}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>

      {/* Image classification card */}
      <div className="bg-white rounded-xl shadow p-6">
        <h2 className="text-xl font-semibold text-slate-800 mb-2">
          🩺 Kiểm tra ảnh cá
        </h2>
        <p className="text-sm text-slate-500 mb-4">
          Upload ảnh cá (từ điện thoại hoặc camera) để AI đánh giá sơ bộ có dấu hiệu bất thường hay không.
        </p>

        <form onSubmit={handleImageSubmit} className="space-y-4">
          <input
            type="file"
            accept="image/*"
            onChange={(e) => {
              setFile(e.target.files?.[0] ?? null);
              setImageResult(null);
              setImageError(null);
            }}
            className="block w-full text-sm text-slate-500
                       file:mr-4 file:py-2 file:px-4
                       file:rounded-full file:border-0
                       file:text-sm file:font-semibold
                       file:bg-blue-50 file:text-blue-700
                       hover:file:bg-blue-100"
          />
          <button
            type="submit"
            disabled={!file || imageLoading}
            className="px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm font-medium hover:bg-emerald-700 disabled:opacity-50"
          >
            {imageLoading ? "Đang gửi ảnh..." : "Gửi ảnh tới AI"}
          </button>
        </form>

        <div className="mt-4">
          {imageError && (
            <div className="text-sm text-red-600">
              Lỗi xử lý ảnh: {imageError}
            </div>
          )}
          {imageResult && (
            <div className="mt-3 text-sm">
              <div className="font-medium mb-1">Kết quả AI:</div>
              <p>
                Nhãn:{" "}
                <span className="font-semibold text-slate-800">
                  {imageResult.label}
                </span>
              </p>
              {typeof imageResult.score === "number" && (
                <p>
                  Độ tin cậy:{" "}
                  <span className="font-semibold text-slate-800">
                    {(imageResult.score * 100).toFixed(1)}%
                  </span>
                </p>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

