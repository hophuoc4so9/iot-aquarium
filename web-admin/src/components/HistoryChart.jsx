import React from "react";
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

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

export default function HistoryChart({
  series = [],
  labels = [],
  title = "History",
}) {
  const data = {
    labels,
    datasets: series.map((s, i) => ({
      label: s.label,
      data: s.data,
      borderColor: s.color,
      backgroundColor: s.color,
      tension: 0.3,
      pointRadius: 2,
    })),
  };

  const options = {
    responsive: true,
    plugins: {
      legend: { position: "top" },
      title: { display: !!title, text: title },
    },
    scales: {
      x: { display: false },
    },
  };

  return (
    <div className="bg-white rounded-xl shadow p-4">
      <Line data={data} options={options} />
    </div>
  );
}
