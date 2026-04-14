import React, { useEffect, useMemo, useRef, useState } from "react";
import { Client } from "@stomp/stompjs";
import SockJS from "sockjs-client/dist/sockjs.min.js";

import AlertsPanel from "./AlertsPanel";
import DashboardOverview from "./DashboardOverview";
import HistoryChart from "./HistoryChart";
import SensorCard from "./SensorCard";
import Toast from "./Toast";
import WaterLevelGauge from "./WaterLevelGauge";

const initial = {
  waterLevel: 50,
  temp: 25.0,
  ph: 7.0,
  floatHigh: false,
  floatLow: false,
  motorRunning: false,
  direction: "STOPPED",
  duty: 0,
  mode: "MANUAL",
  anomalyScore: 0,
  anomalyFlag: false,
  source: "init",
};

export default function Dashboard() {
  const [data, setData] = useState(initial);
  const [toast, setToast] = useState("");
  const [alerts, setAlerts] = useState([]);
  const [history, setHistory] = useState([]);
  const [lastUpdatedAt, setLastUpdatedAt] = useState(null);
  const [connected, setConnected] = useState(false);

  const stompClientRef = useRef(null);
  const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";
  const HISTORY_LIMIT = 60;

  const [thresholds] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem("aq-thresholds")) || {};
    } catch {
      return {};
    }
  });

  const parseBool = (v) => v === true || v === "true" || v === 1 || v === "1";

  const getWaterLevelByFloat = (floatHigh, floatLow) => {
    if (floatHigh && floatLow) return 95;
    if (!floatHigh && floatLow) return 50;
    if (floatHigh && !floatLow) return 20;
    return 15;
  };

  const pushHistoryPoint = (next) => {
    const point = {
      t: new Date(),
      temp: Number.isFinite(next.temp) ? next.temp : null,
      ph: Number.isFinite(next.ph) ? next.ph : null,
      water: Number.isFinite(next.waterLevel) ? next.waterLevel : null,
      anomaly: Number.isFinite(next.anomalyScore) ? next.anomalyScore : 0,
    };

    setHistory((prev) => {
      const merged = [...prev, point];
      return merged.slice(-HISTORY_LIMIT);
    });
  };

  const updateDataFromTelemetry = (payload) => {
    if (!payload || typeof payload !== "object") return;

    setData((prev) => {
      const temp =
        payload.temperature !== undefined && payload.temperature !== null
          ? Number(payload.temperature)
          : prev.temp;
      const ph =
        payload.ph !== undefined && payload.ph !== null
          ? Number(payload.ph)
          : prev.ph;
      const floatHigh =
        payload.floatHigh !== undefined ? parseBool(payload.floatHigh) : prev.floatHigh;
      const floatLow =
        payload.floatLow !== undefined ? parseBool(payload.floatLow) : prev.floatLow;

      const next = {
        ...prev,
        temp,
        ph,
        floatHigh,
        floatLow,
        waterLevel:
          payload.waterLevelPercent !== undefined && payload.waterLevelPercent !== null
            ? Number(payload.waterLevelPercent)
            : getWaterLevelByFloat(floatHigh, floatLow),
        motorRunning:
          payload.motorRunning !== undefined
            ? parseBool(payload.motorRunning)
            : prev.motorRunning,
        direction: payload.direction || prev.direction,
        duty:
          payload.duty !== undefined && payload.duty !== null
            ? Number(payload.duty)
            : prev.duty,
        mode: payload.mode || prev.mode,
        anomalyScore:
          payload.anomalyScore !== undefined && payload.anomalyScore !== null
            ? Number(payload.anomalyScore)
            : prev.anomalyScore,
        anomalyFlag:
          payload.anomalyFlag !== undefined
            ? parseBool(payload.anomalyFlag)
            : prev.anomalyFlag,
        source: payload.source || prev.source,
      };

      pushHistoryPoint(next);
      return next;
    });

    setLastUpdatedAt(new Date());
  };

  const fetchLatest = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/control/status/latest`);
      if (res.ok) {
        const telemetry = await res.json();
        updateDataFromTelemetry(telemetry);
      }
    } catch (e) {
      console.error("Failed to fetch latest status:", e);
    }
  };

  useEffect(() => {
    fetchLatest();
  }, []);

  useEffect(() => {
    const wsUrl = `${API_BASE}/ws`;
    const client = new Client({
      webSocketFactory: () => new SockJS(wsUrl),
      debug: () => {},
      onConnect: () => {
        setConnected(true);
        client.subscribe("/topic/stream", (msg) => {
          try {
            const body = JSON.parse(msg.body);
            if (body && body.data) {
              const payload =
                typeof body.data === "string" ? JSON.parse(body.data) : body.data;
              updateDataFromTelemetry(payload);
            }
          } catch (e) {
            console.error("Invalid WS message", e);
          }
        });
      },
      onStompError: (frame) => {
        console.error("STOMP error", frame);
        setConnected(false);
      },
      onDisconnect: () => {
        setConnected(false);
      },
    });

    stompClientRef.current = client;
    client.activate();

    return () => {
      if (client) client.deactivate();
    };
  }, [API_BASE]);

  const TH = {
    waterLow: 20,
    waterHigh: 85,
    tempLow: 18,
    tempHigh: 30,
    phLow: 6.0,
    phHigh: 8.5,
    ...thresholds,
  };

  const waterAlert =
    data.waterLevel <= TH.waterLow
      ? "Water level LOW"
      : data.waterLevel >= TH.waterHigh
      ? "Water level HIGH"
      : "";

  const tempAlert =
    data.temp < TH.tempLow
      ? "Temperature too LOW"
      : data.temp > TH.tempHigh
      ? "Temperature too HIGH"
      : "";

  const phAlert =
    data.ph < TH.phLow
      ? "pH too LOW (acidic)"
      : data.ph > TH.phHigh
      ? "pH too HIGH (alkaline)"
      : "";

  const anomalyAlert = data.anomalyFlag
    ? `Anomaly score HIGH (${data.anomalyScore.toFixed(3)})`
    : "";

  useEffect(() => {
    const messages = [waterAlert, tempAlert, phAlert, anomalyAlert].filter(Boolean);
    if (messages.length > 0) {
      const msg = messages.join(" • ");
      setToast(msg);
      setAlerts((a) => [
        ...a.slice(-49),
        { message: msg, ts: new Date().toLocaleString(), level: "WARN" },
      ]);

      const t = setTimeout(() => setToast(""), 6000);
      return () => clearTimeout(t);
    }

    return undefined;
  }, [waterAlert, tempAlert, phAlert, anomalyAlert]);

  const chartLabels = useMemo(
    () => history.map((item) => item.t.toLocaleTimeString()),
    [history]
  );

  const chartSeries = useMemo(
    () => [
      {
        label: "Temperature (C)",
        data: history.map((item) => item.temp),
        color: "#ea580c",
      },
      {
        label: "pH",
        data: history.map((item) => item.ph),
        color: "#0d9488",
      },
      {
        label: "Water Level (%)",
        data: history.map((item) => item.water),
        color: "#0284c7",
      },
    ],
    [history]
  );

  const anomalySeries = useMemo(
    () => [
      {
        label: "Anomaly Score",
        data: history.map((item) => item.anomaly),
        color: "#7c3aed",
      },
    ],
    [history]
  );

  const alertCountNow = [waterAlert, tempAlert, phAlert, anomalyAlert].filter(Boolean).length;

  return (
    <div className="space-y-6">
      <div className="rounded-2xl bg-gradient-to-r from-slate-900 via-cyan-900 to-teal-800 text-white p-6 shadow-lg">
        <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Admin Dashboard</h1>
            <p className="text-cyan-50 text-sm mt-1">
              Giam sat trang thai ao nuoi theo thoi gian thuc, bao gom sensor, ket noi va canh bao bat thuong.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={fetchLatest}
              className="rounded-lg bg-white/15 px-3 py-2 text-sm hover:bg-white/25 transition"
            >
              Lam moi du lieu
            </button>
            <div
              className={`inline-flex items-center rounded-full px-3 py-2 text-sm font-medium ${
                connected
                  ? "bg-emerald-100/20 text-emerald-50"
                  : "bg-rose-100/20 text-rose-50"
              }`}
            >
              {connected ? "● Da ket noi thiet bi" : "○ Mat ket noi thiet bi"}
            </div>
          </div>
        </div>
      </div>

      <DashboardOverview
        totalPonds={1}
        safeCount={alertCountNow === 0 ? 1 : 0}
        alertCount={alertCountNow > 0 ? 1 : 0}
        deviceConnected={connected}
      />

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <div className="xl:col-span-2 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <SensorCard
              title="Temperature"
              value={Number.isFinite(data.temp) ? data.temp.toFixed(1) : "--"}
              unit="C"
              alert={tempAlert}
              ranges={[
                { max: TH.tempLow, color: "bg-sky-300", label: "Low" },
                { max: TH.tempHigh, color: "bg-emerald-400", label: "Normal" },
                { max: 99, color: "bg-rose-400", label: "High" },
              ]}
            />
            <SensorCard
              title="pH"
              value={Number.isFinite(data.ph) ? data.ph.toFixed(2) : "--"}
              unit=""
              alert={phAlert}
              ranges={[
                { max: TH.phLow, color: "bg-amber-300", label: "Acidic" },
                { max: TH.phHigh, color: "bg-emerald-400", label: "Safe" },
                { max: 14, color: "bg-fuchsia-300", label: "Alkaline" },
              ]}
            />
            <SensorCard
              title="Anomaly"
              value={
                Number.isFinite(data.anomalyScore)
                  ? data.anomalyScore.toFixed(3)
                  : "0.000"
              }
              unit="score"
              alert={anomalyAlert}
              ranges={[
                { max: 0.05, color: "bg-emerald-400", label: "Stable" },
                { max: 0.12, color: "bg-amber-300", label: "Watch" },
                { max: 2, color: "bg-rose-400", label: "Critical" },
              ]}
            />
          </div>

          <HistoryChart
            series={chartSeries}
            labels={chartLabels}
            title="Realtime Sensor Trends"
          />
          <HistoryChart
            series={anomalySeries}
            labels={chartLabels}
            title="Anomaly Score Trend"
          />
        </div>

        <div className="space-y-6">
          <div className="bg-white rounded-xl shadow p-5">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-slate-800">Water Level</h2>
              <span className="text-xs text-slate-500">
                {lastUpdatedAt ? lastUpdatedAt.toLocaleTimeString() : "--:--:--"}
              </span>
            </div>
            <WaterLevelGauge
              value={Number.isFinite(data.waterLevel) ? data.waterLevel : 0}
              floatHigh={data.floatHigh}
              floatLow={data.floatLow}
            />
          </div>

          <div className="bg-white rounded-xl shadow p-5">
            <h2 className="text-lg font-semibold text-slate-800 mb-4">Device Snapshot</h2>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-slate-500">Mode</span>
                <span className="font-medium">{data.mode}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Motor</span>
                <span className={`font-medium ${data.motorRunning ? "text-emerald-600" : "text-slate-600"}`}>
                  {data.motorRunning ? "Running" : "Stopped"}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Direction</span>
                <span className="font-medium">{data.direction}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Duty</span>
                <span className="font-medium">{data.duty}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Source</span>
                <span className="font-medium">{data.source || "esp32"}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Float HIGH</span>
                <span className="font-medium">{data.floatHigh ? "true" : "false"}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Float LOW</span>
                <span className="font-medium">{data.floatLow ? "true" : "false"}</span>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow p-5">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-lg font-semibold text-slate-800">Alerts</h2>
              <button
                type="button"
                onClick={() => setAlerts([])}
                className="text-xs rounded border border-slate-200 px-2 py-1 hover:bg-slate-50"
              >
                Xoa lich su
              </button>
            </div>
            <AlertsPanel alerts={alerts} />
          </div>
        </div>
      </div>

      <Toast
        message={toast}
        type={
          toast
            ? toast.includes("too") ||
              toast.includes("LOW") ||
              toast.includes("HIGH")
              ? "warn"
              : "info"
            : "info"
        }
      />
    </div>
  );
}
