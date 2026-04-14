import React, { useState } from "react";
import { appendDiagnosisLog } from "../lib/storage";

/**
 * AI Panel
 * - Upload ảnh cá để kiểm tra dấu hiệu bệnh. Kết quả được ghi vào Nhật ký chẩn đoán.
 */
export default function AiPanel() {
  const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

  async function parseApiError(res, fallbackMessage) {
    try {
      const data = await res.json();
      if (data?.message) return `${fallbackMessage}: ${data.message}`;
      if (data?.detail) return `${fallbackMessage}: ${data.detail}`;
      if (data?.error) return `${fallbackMessage}: ${data.error}`;
    } catch {
      // Ignore JSON parse errors and keep fallback.
    }
    return `${fallbackMessage} (HTTP ${res.status})`;
  }

  const [file, setFile] = useState(null);
  const [imageLoading, setImageLoading] = useState(false);
  const [imageResult, setImageResult] = useState(null);
  const [imageError, setImageError] = useState(null);

  async function handleImageSubmit(e) {
    e.preventDefault();
    if (!file) return;
    setImageLoading(true);
    setImageError(null);
    setImageResult(null);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await fetch(`${API_BASE}/api/ai/fish-disease`, {
        method: "POST",
        body: formData,
      });
      if (!res.ok) {
        throw new Error(await parseApiError(res, "Gọi AI chẩn đoán thất bại"));
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
    <div className="grid grid-cols-1 gap-6">
      <div className="bg-white rounded-xl shadow p-6 border border-slate-100">
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

