import React from "react";

export default function WaterLevelGauge({ value = 0, floatHigh, floatLow }) {
  const level = Math.max(0, Math.min(100, Math.round(value)));

  const status =
    floatHigh && floatLow
      ? { label: "Muc nuoc cao", className: "text-cyan-600" }
      : floatHigh && !floatLow
      ? { label: "Can kiem tra cam bien", className: "text-rose-600" }
      : !floatHigh && floatLow
      ? { label: "Muc nuoc on dinh", className: "text-emerald-600" }
      : { label: "Muc nuoc thap", className: "text-amber-600" };

  const helperText =
    level < 25
      ? "Nen bo sung nuoc trong som."
      : level > 85
      ? "Muc nuoc dang cao, theo doi them."
      : "Thong so dang trong nguong on dinh.";
  
  return (
    <div className="flex items-center gap-6">
      <div className="w-36 h-56 bg-gradient-to-b from-sky-100 to-sky-300 rounded-xl relative overflow-hidden shadow-inner">
        <div
          className="absolute bottom-0 left-0 right-0 transition-all duration-700 ease-out"
          style={{ height: `${level}%` }}
        >
          <div className="h-full bg-gradient-to-b from-sky-600 to-sky-400 opacity-90 flex items-center justify-center text-white text-xl font-bold">
            {level}%
          </div>
        </div>
      </div>
      <div className="flex-1">
        <div className="text-sm text-slate-500 mb-2">Status</div>
        <div className="text-lg font-medium">
          <span className={status.className}>{status.label}</span>
        </div>
        <div className="mt-3 rounded-lg bg-slate-50 border border-slate-200 p-3 text-sm text-slate-600">
          {helperText}
        </div>
      </div>
    </div>
  );
}
