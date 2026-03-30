import React from "react";

/**
 * Bảng điều khiển tổng quan: tóm tắt ao an toàn, ao cảnh báo, trạng thái thiết bị IoT.
 */
export default function DashboardOverview({ totalPonds = 1, safeCount = 0, alertCount = 0, deviceConnected = false }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
      <div className="bg-white rounded-xl shadow p-5 border-l-4 border-emerald-500">
        <div className="text-sm font-medium text-slate-500">Ao an toàn</div>
        <div className="text-2xl font-bold text-emerald-600 mt-1">{safeCount}</div>
        <div className="text-xs text-slate-400 mt-1">/ {totalPonds} ao tổng</div>
      </div>
      <div className="bg-white rounded-xl shadow p-5 border-l-4 border-amber-500">
        <div className="text-sm font-medium text-slate-500">Ao có cảnh báo</div>
        <div className="text-2xl font-bold text-amber-600 mt-1">{alertCount}</div>
        <div className="text-xs text-slate-400 mt-1">Cần kiểm tra</div>
      </div>
      <div className="bg-white rounded-xl shadow p-5 border-l-4 border-slate-400">
        <div className="text-sm font-medium text-slate-500">Thiết bị IoT</div>
        <div className={`text-lg font-bold mt-1 ${deviceConnected ? "text-emerald-600" : "text-red-600"}`}>
          {deviceConnected ? "● Đã kết nối" : "○ Mất kết nối"}
        </div>
        <div className="text-xs text-slate-400 mt-1">
          {deviceConnected ? "Nhận dữ liệu realtime" : "Đang chờ kết nối lại"}
        </div>
      </div>
    </div>
  );
}
