import React, { useState, useEffect } from "react";
import { getDiagnosisLog } from "../lib/storage";

export default function DiagnosisLog() {
  const [log, setLog] = useState([]);

  useEffect(() => {
    setLog(getDiagnosisLog());
  }, []);

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold text-slate-800">Nhật ký chẩn đoán bệnh cá</h2>
      <p className="text-sm text-slate-500">
        Lịch sử các lần chẩn đoán bệnh cá bằng hình ảnh, kết quả xử lý và tình trạng phục hồi.
      </p>

      <div className="bg-white rounded-xl shadow overflow-hidden">
        <table className="min-w-full divide-y divide-slate-200">
          <thead className="bg-slate-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Thời gian</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Ảnh / Mô tả</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Kết quả chẩn đoán</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Độ tin cậy</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Tình trạng phục hồi</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-200">
            {log.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                  Chưa có bản ghi. Sử dụng mục "AI Assistant" → Kiểm tra ảnh cá để thêm bản ghi.
                </td>
              </tr>
            )}
            {log.map((entry) => (
              <tr key={entry.id} className="hover:bg-slate-50">
                <td className="px-4 py-3 text-sm text-slate-600">
                  {entry.createdAt ? new Date(entry.createdAt).toLocaleString("vi-VN") : "—"}
                </td>
                <td className="px-4 py-3">
                  {entry.imageUrl ? (
                    <img src={entry.imageUrl} alt="Cá" className="h-12 w-12 object-cover rounded" />
                  ) : (
                    <span className="text-sm text-slate-500">{entry.fileName || "Ảnh đã gửi"}</span>
                  )}
                </td>
                <td className="px-4 py-3 text-sm font-medium text-slate-800">{entry.label ?? entry.result ?? "—"}</td>
                <td className="px-4 py-3 text-sm text-slate-600">
                  {entry.score != null ? `${(Number(entry.score) * 100).toFixed(1)}%` : "—"}
                </td>
                <td className="px-4 py-3 text-sm text-slate-600">{entry.recoveryStatus ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
