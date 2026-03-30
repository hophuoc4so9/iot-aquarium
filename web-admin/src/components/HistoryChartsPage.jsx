import React, { useEffect, useState } from "react";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";
import { Line, Bar } from "react-chartjs-2";

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend
);

const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

function buildChartData(records, range) {
  const now = Date.now();
  const ms = { day: 24 * 60 * 60 * 1000, week: 7 * 24 * 60 * 60 * 1000, month: 30 * 24 * 60 * 60 * 1000 }[range] || 24 * 60 * 60 * 1000;
  const cutoff = now - ms;
  const list = (records || [])
    .filter((r) => r.timestamp && new Date(r.timestamp).getTime() >= cutoff)
    .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
  const labels = list.map((r) => {
    const d = new Date(r.timestamp);
    return range === "day" ? d.toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) : d.toLocaleDateString("vi-VN", { day: "2-digit", month: "2-digit" });
  });
  const water = list.map((r) => {
    if (r.waterLevelPercent != null) return Number(r.waterLevelPercent);
    if (r.floatHigh && r.floatLow) return 95;
    if (!r.floatHigh && r.floatLow) return 50;
    if (!r.floatHigh && !r.floatLow) return 15;
    return 50;
  });
  const temp = list.map((r) => (r.temperature != null ? Number(r.temperature) : null));
  const ph = list.map((r) => (r.ph != null ? Number(r.ph) : null));
  return {
    labels,
    datasets: [
      { label: "Mực nước %", data: water, borderColor: "rgba(14,165,233,0.9)", backgroundColor: "rgba(14,165,233,0.2)", tension: 0.3 },
      { label: "Nhiệt độ °C", data: temp, borderColor: "rgba(234,88,12,0.9)", backgroundColor: "rgba(234,88,12,0.2)", tension: 0.3 },
      { label: "pH", data: ph, borderColor: "rgba(34,197,94,0.9)", backgroundColor: "rgba(34,197,94,0.2)", tension: 0.3 },
    ],
  };
}

export default function HistoryChartsPage({ pondId }) {
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [range, setRange] = useState("day");
  const [chartType, setChartType] = useState("line");

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetch(`${API_BASE}/api/telemetry/recent`)
      .then((r) => r.ok ? r.json() : [])
      .then((data) => {
        if (!cancelled) setRecords(Array.isArray(data) ? data : []);
      })
      .catch(() => { if (!cancelled) setRecords([]); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, []);

  const filtered = pondId
    ? (records || []).filter((r) => String(r.pondId) === String(pondId))
    : records;

  const chartData = buildChartData(filtered, range);
  const ChartComponent = chartType === "bar" ? Bar : Line;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h2 className="text-xl font-semibold text-slate-800">Giám sát & phân tích biểu đồ</h2>
        <div className="flex flex-wrap gap-3">
          <select
            value={range}
            onChange={(e) => setRange(e.target.value)}
            className="px-3 py-2 border border-slate-300 rounded-lg text-sm"
          >
            <option value="day">Theo ngày</option>
            <option value="week">Theo tuần</option>
            <option value="month">Theo tháng</option>
          </select>
          <select
            value={chartType}
            onChange={(e) => setChartType(e.target.value)}
            className="px-3 py-2 border border-slate-300 rounded-lg text-sm"
          >
            <option value="line">Đường</option>
            <option value="bar">Cột</option>
          </select>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow p-6">
        <p className="text-sm text-slate-500 mb-4">
          Dữ liệu môi trường (nhiệt độ, pH, mực nước) theo thời gian thực và lịch sử.
        </p>
        {loading && <p className="text-slate-500">Đang tải...</p>}
        {!loading && chartData.labels.length === 0 && (
          <p className="text-slate-500">Chưa có dữ liệu trong khoảng đã chọn.</p>
        )}
        {!loading && chartData.labels.length > 0 && (
          <ChartComponent
            data={chartData}
            options={{
              responsive: true,
              plugins: { legend: { position: "top" }, title: { display: true, text: "Nhiệt độ, pH, mực nước" } },
              scales: { x: { display: true, maxRotation: 45 } },
            }}
          />
        )}
      </div>
    </div>
  );
}
