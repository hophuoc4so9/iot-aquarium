import React, { useEffect, useState, useRef } from "react";
// Web-admin chỉ dùng để GIÁM SÁT, không điều khiển từ xa
import Toast from "./Toast";
import SockJS from "sockjs-client/dist/sockjs.min.js";
import { Client } from "@stomp/stompjs";
import AlertsPanel from "./AlertsPanel";

const initial = {
  waterLevel: 50,
  temp: 25.0,
  ph: 7.0,
  floatHigh: false,
  floatLow: false,
};

export default function Dashboard() {
  const [data, setData] = useState(initial);
  const [toast, setToast] = useState("");
  const [alerts, setAlerts] = useState([]);
  const [thresholds] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem("aq-thresholds")) || {};
    } catch (e) {
      return {};
    }
  });

  const stompClientRef = useRef(null);
  const [connected, setConnected] = useState(false);
  const mockIntervalRef = useRef(null);
  const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

  // Fetch latest status from backend on mount
  useEffect(() => {
    async function fetchLatest() {
      try {
        const res = await fetch(`${API_BASE}/api/control/status/latest`);
        if (res.ok) {
          const telemetry = await res.json();
          console.log("Latest telemetry:", telemetry);
          updateDataFromTelemetry(telemetry);
        }
      } catch (e) {
        console.error("Failed to fetch latest status:", e);
      }
    }
    fetchLatest();
  }, []);

  function updateDataFromTelemetry(payload) {
    // Map ESP32 telemetry fields to UI state
    console.log('[Dashboard] Received telemetry:', payload);
    const newData = { ...data };
    
    if (payload.temperature !== undefined && payload.temperature !== null) {
      newData.temp = parseFloat(payload.temperature);
    }
    
    if (payload.ph !== undefined && payload.ph !== null) {
      newData.ph = parseFloat(payload.ph);
    }
    
    if (payload.floatHigh !== undefined) {
      newData.floatHigh = payload.floatHigh === true || payload.floatHigh === "true";
      console.log('[Dashboard] floatHigh:', payload.floatHigh, '->', newData.floatHigh);
    }
    
    if (payload.floatLow !== undefined) {
      newData.floatLow = payload.floatLow === true || payload.floatLow === "true";
      console.log('[Dashboard] floatLow:', payload.floatLow, '->', newData.floatLow);
    }
    
    // Calculate water level percentage from float switches
    // Logic: floatXXX = true nghĩa là phao đã nổi (có nước ở mức đó)
    // floatHigh=true AND floatLow=true  -> Tank FULL (95%) - cả 2 phao đều nổi
    // floatHigh=false AND floatLow=true -> Normal level (50%) - chỉ phao thấp nổi
    // floatHigh=true AND floatLow=false -> IMPOSSIBLE (phao cao nổi mà phao thấp chưa nổi???)
    // floatHigh=false AND floatLow=false -> LOW level (15%) - cả 2 phao đều chưa nổi
    if (newData.floatHigh && newData.floatLow) {
      newData.waterLevel = 95;  // Tank full - cả 2 phao đều nổi
    } else if (!newData.floatHigh && newData.floatLow) {
      newData.waterLevel = 50;  // Normal level - chỉ phao thấp nổi
    } else if (newData.floatHigh && !newData.floatLow) {
      // Impossible case: phao cao nổi nhưng phao thấp chưa nổi
      // Có thể do lỗi phần cứng hoặc đấu dây sai
      newData.waterLevel = 20;  
      console.warn('[Dashboard] ⚠️ IMPOSSIBLE STATE: floatHigh=true but floatLow=false!');
    } else {
      newData.waterLevel = 15;  // Low level - cả 2 phao đều chưa nổi (cần châm nước gấp!)
    }
    
    setData(newData);
  }

  useEffect(() => {
    // Setup STOMP client and connect to backend WebSocket
    // SockJS requires http:// or https:// URL, NOT ws://
    const wsUrl = `${API_BASE}/ws`;
    console.log("Connecting to WebSocket:", wsUrl);
    
    const client = new Client({
      webSocketFactory: () => new SockJS(wsUrl),
      debug: function (str) {
        console.log("STOMP:", str);
      },
      onConnect: (frame) => {
        console.log("WebSocket connected!");
        setConnected(true);
        
        client.subscribe("/topic/stream", (msg) => {
          try {
            const body = JSON.parse(msg.body);
            console.log("WebSocket message:", body);
            
            if (body && body.data) {
              const payload = typeof body.data === "string" ? JSON.parse(body.data) : body.data;
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
        console.log("WebSocket disconnected");
        setConnected(false);
      },
    });
    
    stompClientRef.current = client;
    client.activate();

    return () => {
      if (client) {
        client.deactivate();
      }
    };
  }, []);

  // Threshold checks -> produce alerts
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

  useEffect(() => {
    const messages = [waterAlert, tempAlert, phAlert].filter(Boolean);
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
    }, [waterAlert, tempAlert, phAlert]);

  return (
    <div className="space-y-6">
      <div className="rounded-2xl bg-gradient-to-r from-cyan-700 via-teal-700 to-emerald-700 text-white p-6 shadow-lg">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Aquarium Monitoring Dashboard</h1>
            <p className="text-cyan-50 text-sm mt-1">Theo doi muc nuoc, nhiet do va pH theo thoi gian thuc.</p>
          </div>
          <div className={`inline-flex items-center rounded-full px-3 py-1 text-sm font-medium ${connected ? "bg-emerald-100/20 text-emerald-50" : "bg-rose-100/20 text-rose-50"}`}>
            {connected ? "● Da ket noi thiet bi" : "○ Mat ket noi thiet bi"}
          </div>
        </div>
      </div>
      <div className="bg-white rounded-xl shadow p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-medium text-slate-800">Canh bao he thong</h2>
          <span className="text-sm text-slate-500">Last updated: {new Date().toLocaleTimeString()}</span>
        </div>
        <AlertsPanel alerts={alerts} />
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
