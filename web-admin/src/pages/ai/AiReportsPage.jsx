import React from "react";
import AiPanel from "../../components/AiPanel";
import FederatedLearningPage from "../fl/FederatedLearningPage";

function Badge({ children }) {
  return (
    <span className="inline-flex items-center rounded-full bg-amber-100 px-2.5 py-1 text-xs font-semibold text-amber-800">
      {children}
    </span>
  );
}

export default function AiReportsPage() {
  return (
    <div className="space-y-6">
      <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
        <div className="flex flex-wrap items-center gap-2 mb-3">
          <h4 className="text-lg font-semibold text-slate-800">AI Reports</h4>
          <Badge>AI fallback</Badge>
        </div>
        <p className="text-sm text-slate-500 mb-4">
          Màn hình admin hiển thị an toàn khi alerts backend chưa có dữ liệu ao hoặc telemetry.
        </p>
        <AiPanel />
      </div>

      <section className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
        <div className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between mb-4">
          <div>
            <h4 className="text-lg font-semibold text-slate-800">Federated Learning</h4>
            <p className="text-sm text-slate-500">
              Điều phối model global, round train và upload update ngay trong cùng màn hình AI & Báo cáo.
            </p>
          </div>
        </div>
        <FederatedLearningPage />
      </section>
    </div>
  );
}
