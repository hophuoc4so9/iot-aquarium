import React, { useState } from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend);

const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

export default function AiForecastReport() {
  const [metric, setMetric] = useState("PH");
  const [horizon, setHorizon] = useState(6);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);

  async function runForecast() {
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const params = new URLSearchParams({ pondId: "1", metric, horizonHours: String(horizon) });
      const res = await fetch(`${API_BASE}/api/ai/forecast?${params.toString()}`, { method: "POST" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setResult(data);
    } catch (e) {
      setError(String(e.message || e));
    } finally {
      setLoading(false);
    }
  }

  const labels = result?.points?.map((p) => p.timestamp) || [];
  const values = result?.points?.map((p) => (typeof p.value === "number" ? p.value : parseFloat(p.value))) || [];
  const chartData = {
    labels,
    datasets: [
      {
        label: metric === "PH" ? "pH dự báo" : "Nhiệt độ (°C) dự báo",
        data: values,
        borderColor: "rgba(59,130,246,0.9)",
        backgroundColor: "rgba(59,130,246,0.2)",
        tension: 0.3,
      },
    ],
  };

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold text-slate-800">Báo cáo dự báo từ AI</h2>
      <p className="text-sm text-slate-500">
        Phân tích và biểu đồ dự báo xu hướng chất lượng nước (pH / nhiệt độ) trong tương lai gần.
      </p>

      <div className="bg-white rounded-xl shadow p-6">
        <div className="flex flex-wrap gap-4 mb-4">
          <div>
            <label className="block text-xs text-slate-600 mb-1">Chỉ số</label>
            <select
              value={metric}
              onChange={(e) => setMetric(e.target.value)}
              className="px-3 py-2 border rounded-lg text-sm"
            >
              <option value="PH">pH</option>
              <option value="TEMP">Nhiệt độ</option>
            </select>
          </div>
          <div>
            <label className="block text-xs text-slate-600 mb-1">Thời gian dự báo (giờ)</label>
            <select
              value={horizon}
              onChange={(e) => setHorizon(Number(e.target.value))}
              className="px-3 py-2 border rounded-lg text-sm"
            >
              <option value={1}>1</option>
              <option value={3}>3</option>
              <option value={6}>6</option>
            </select>
          </div>
          <div className="flex items-end">
            <button
              onClick={runForecast}
              disabled={loading}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50"
            >
              {loading ? "Đang tải..." : "Tạo báo cáo dự báo"}
            </button>
          </div>
        </div>

        {error && <div className="text-sm text-red-600 mb-4">Lỗi: {error}</div>}

        {result && (
          <>
            {Array.isArray(result.points) && result.points.length > 0 && (
              <div className="mt-4">
                <Line
                  data={chartData}
                  options={{
                    responsive: true,
                    plugins: { legend: { position: "top" }, title: { display: true, text: "Xu hướng dự báo" } },
                    scales: { x: { display: true, maxRotation: 45 } },
                  }}
                />
              </div>
            )}
            {result.summary && (
              <div className="mt-4 p-3 bg-slate-50 rounded-lg text-sm text-slate-700">
                <strong>Tóm tắt:</strong> {result.summary}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
