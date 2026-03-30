import React from "react";
import clsx from "clsx";

function RangePill({ ranges, value }) {
  const active =
    ranges.find((r) => value <= r.max) || ranges[ranges.length - 1];
  return (
    <div className="mt-3 flex items-center gap-2">
      {ranges.map((r, i) => (
        <div
          key={i}
          className={clsx(
            "flex-1 h-3 rounded-full",
            r.color,
            value <= r.max
              ? "opacity-100 ring-2 ring-offset-1 ring-slate-200"
              : "opacity-40"
          )}
        ></div>
      ))}
      <div className="ml-3 text-xs text-slate-500">{active.label}</div>
    </div>
  );
}

export default function SensorCard({ title, value, unit, ranges = [], alert }) {
  const isAlert = !!alert;
  return (
    <div
      className={`bg-white rounded-xl shadow p-5 ${
        isAlert ? "ring-2 ring-rose-200" : ""
      }`}
    >
      <div className="flex items-start justify-between">
        <div>
          <h3 className="text-lg font-medium flex items-center gap-3">
            {title}
            {isAlert && (
              <span className="text-xs bg-rose-100 text-rose-700 px-2 py-0.5 rounded">
                Alert
              </span>
            )}
          </h3>
          <div className="text-3xl font-semibold mt-2">
            {value} <span className="text-sm text-slate-500">{unit}</span>
          </div>
        </div>
      </div>
      {ranges.length > 0 && <RangePill ranges={ranges} value={value} />}
      {isAlert && <div className="mt-3 text-sm text-rose-600">{alert}</div>}
    </div>
  );
}
