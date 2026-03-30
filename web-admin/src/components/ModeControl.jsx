import React, { useState, useEffect } from "react";

/**
 * (Không còn dùng để điều khiển) – nếu sau này cần có thể dùng lại cho trang vận hành.
 * Giữ file để app-user/khác có thể tái sử dụng, nhưng không được render trong web-admin.
 */
export default function ModeControl({ currentMode }) {
  const [mode, setMode] = useState(currentMode || "AUTO");

  useEffect(() => {
    if (currentMode) setMode(currentMode);
  }, [currentMode]);

  return (
    <div className="bg-white rounded-xl shadow p-6">
      <h2 className="text-xl font-medium mb-4">Control Mode</h2>
      <div className="flex gap-3">
        <button
          disabled
          className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors ${
            mode === "AUTO"
              ? "bg-blue-600 text-white"
              : "bg-gray-100 text-gray-700 hover:bg-gray-200"
          }`}
        >
          🤖 AUTO Mode
        </button>
        <button
          disabled
          className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors ${
            mode === "MANUAL"
              ? "bg-orange-600 text-white"
              : "bg-gray-100 text-gray-700 hover:bg-gray-200"
          }`}
        >
          ✋ MANUAL Mode
        </button>
      </div>
      <div className="mt-4 text-sm text-gray-600">
        <p className="mb-2">
          <strong>Current Mode:</strong>{" "}
          <span className={mode === "AUTO" ? "text-blue-600" : "text-orange-600"}>
            {mode}
          </span>
        </p>
        <p className="text-xs">
          {mode === "AUTO"
            ? "⚙️ Trạng thái chế độ hiện tại (chỉ hiển thị cho admin)"
            : "✋ Manual mode – thao tác điều khiển thực hiện từ app người nuôi"}
        </p>
      </div>
    </div>
  );
}
