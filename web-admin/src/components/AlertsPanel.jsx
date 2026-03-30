import React from "react";

export default function AlertsPanel({ alerts = [] }) {
  if (!alerts || alerts.length === 0)
    return (
      <div className="bg-white rounded-xl shadow p-4 text-sm text-slate-500">
        No alerts
      </div>
    );
  return (
    <div className="bg-white rounded-xl shadow p-4">
      <h3 className="font-medium mb-2">Recent Alerts</h3>
      <ul className="text-sm space-y-2 max-h-48 overflow-auto">
        {alerts.map((a, i) => (
          <li key={i} className="flex justify-between items-start">
            <div>
              <div className="text-slate-700">{a.message}</div>
              <div className="text-xs text-slate-400">{a.ts}</div>
            </div>
            <div className="text-xs text-rose-600">{a.level || "WARN"}</div>
          </li>
        ))}
      </ul>
    </div>
  );
}
