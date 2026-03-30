import React, { useState, useEffect } from "react";

export default function ControlButtons({
  onPumpToggle,
  pumpOn,
  onRefill,
  deviceId,
  motorDirection, // Receive actual motor direction from parent
}) {
  const API_BASE = import.meta.env.VITE_API_BASE ?? "";
  const [motorStatus, setMotorStatus] = useState("STOP"); // STOP, FORWARD, BACKWARD

  // Sync with actual motor direction from ESP32
  useEffect(() => {
    if (motorDirection) {
      setMotorStatus(motorDirection);
      console.log("[ControlButtons] Synced motor direction:", motorDirection);
    }
  }, [motorDirection]);

  async function callMotorCommand(cmd, params = {}) {
    try {
      // Build query string
      const qp = new URLSearchParams({ cmd, ...params }).toString();
      const url = `${API_BASE}/api/control/motor?${qp}`;
      const res = await fetch(url, { method: "POST" });
      if (res.ok) {
        console.log(`Motor command ${cmd} sent successfully`);
      }
      return res.ok;
    } catch (e) {
      console.error("Motor command error:", e);
      return false;
    }
  }

  async function handleForward() {
    const ok = await callMotorCommand("FORWARD");
    if (ok) {
      setMotorStatus("FORWARD");
      onPumpToggle && onPumpToggle(true);
    }
  }

  async function handleBackward() {
    const ok = await callMotorCommand("BACKWARD");
    if (ok) {
      setMotorStatus("BACKWARD");
      onPumpToggle && onPumpToggle(true);
    }
  }

  async function handleStop() {
    const ok = await callMotorCommand("STOP");
    if (ok) {
      setMotorStatus("STOP");
      onPumpToggle && onPumpToggle(false);
    }
  }

  async function handleRefill() {
    // Try calling backend motor with DUTY (duty example 600)
    const ok = await callMotorCommand("DUTY", { duty: 600 });
    onRefill && onRefill();
    return ok;
  }

  return (
    <div className="mt-4 space-y-3">
      <div className="text-sm font-medium text-gray-700 mb-2">
        Manual Pump Control
      </div>
      
      {/* Main motor control buttons */}
      <div className="grid grid-cols-3 gap-3">
        <button
          onClick={handleForward}
          disabled={motorStatus === "FORWARD"}
          className={`px-4 py-3 rounded-lg font-medium transition-all ${
            motorStatus === "FORWARD"
              ? "bg-green-600 text-white shadow-lg"
              : "bg-gray-100 text-gray-700 hover:bg-green-100 hover:text-green-700"
          }`}
        >
          <div className="text-xl mb-1">⬆️</div>
          <div className="text-xs">Bơm lên</div>
        </button>
        
        <button
          onClick={handleStop}
          disabled={motorStatus === "STOP"}
          className={`px-4 py-3 rounded-lg font-medium transition-all ${
            motorStatus === "STOP"
              ? "bg-gray-600 text-white shadow-lg"
              : "bg-gray-100 text-gray-700 hover:bg-gray-200"
          }`}
        >
          <div className="text-xl mb-1">⏹️</div>
          <div className="text-xs">Dừng</div>
        </button>
        
        <button
          onClick={handleBackward}
          disabled={motorStatus === "BACKWARD"}
          className={`px-4 py-3 rounded-lg font-medium transition-all ${
            motorStatus === "BACKWARD"
              ? "bg-orange-600 text-white shadow-lg"
              : "bg-gray-100 text-gray-700 hover:bg-orange-100 hover:text-orange-700"
          }`}
        >
          <div className="text-xl mb-1">⬇️</div>
          <div className="text-xs">Hút xuống</div>
        </button>
      </div>
      
      {/* Refill button (separate utility) */}
      <button
        onClick={handleRefill}
        className="w-full px-4 py-2 rounded-lg bg-blue-600 text-white font-medium hover:bg-blue-700 transition-colors"
      >
        🔄 Refill (Duty 600)
      </button>
      
      {/* Status indicator */}
      <div className="text-center text-sm">
        Status: <span className={`font-bold ${
          motorStatus === "FORWARD" ? "text-green-600" :
          motorStatus === "BACKWARD" ? "text-orange-600" :
          "text-gray-600"
        }`}>
          {motorStatus === "FORWARD" ? "⬆️ PUMPING UP" :
           motorStatus === "BACKWARD" ? "⬇️ DRAINING DOWN" :
           "⏹️ STOPPED"}
        </span>
      </div>
    </div>
  );
}
