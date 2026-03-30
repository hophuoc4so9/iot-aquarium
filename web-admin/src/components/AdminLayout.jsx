import React from "react";

const NAV_GROUPS = [
  {
    label: "Tổng quan",
    items: [{ key: "dashboard", label: "Trang chủ", icon: "📊" }],
  },
  {
    label: "Quản lý",
    items: [
      { key: "ponds", label: "Ao / Bể nuôi", icon: "🏞️" },
      { key: "users", label: "Người dùng", icon: "👤" },
    ],
  },
  {
    label: "Cảnh báo",
    items: [
      { key: "threshold-config", label: "Cấu hình ngưỡng", icon: "🚨" },
      { key: "thresholds", label: "Loài cá & Ngưỡng", icon: "🎯" },
    ],
  },
  {
    label: "AI & Báo cáo",
    items: [
      { key: "ai", label: "Dự báo & Chẩn đoán ảnh", icon: "🤖" },
      { key: "diagnosis-log", label: "Nhật ký chẩn đoán", icon: "📚" },
      { key: "chat-history", label: "Lịch sử Chat tư vấn", icon: "💬" },
    ],
  },
];

export default function AdminLayout({ activeTab, onTabChange, onLogout, currentUser, children }) {
  return (
    <div className="min-h-screen flex bg-slate-100">
      {/* Sidebar */}
      <aside className="w-60 min-h-screen bg-slate-800 text-white flex-shrink-0 shadow-xl">
        <div className="p-4 border-b border-slate-700">
          <h1 className="text-lg font-bold text-white truncate">🐠 Smart Aquarium</h1>
          <p className="text-xs text-slate-400 mt-0.5">Quản trị hệ thống</p>
        </div>
        <nav className="p-3 space-y-6 overflow-y-auto">
          {NAV_GROUPS.map((group) => (
            <div key={group.label}>
              <div className="px-3 py-1.5 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                {group.label}
              </div>
              <ul className="mt-1 space-y-0.5">
                {group.items.map((item) => (
                  <li key={item.key}>
                    <button
                      type="button"
                      onClick={() => onTabChange(item.key)}
                      className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                        activeTab === item.key
                          ? "bg-sky-600 text-white"
                          : "text-slate-300 hover:bg-slate-700 hover:text-white"
                      }`}
                    >
                      <span className="text-base">{item.icon}</span>
                      <span className="truncate">{item.label}</span>
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="bg-white border-b border-slate-200 px-6 py-4 flex-shrink-0">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h2 className="text-xl font-semibold text-slate-800">
                {NAV_GROUPS.flatMap((g) => g.items).find((i) => i.key === activeTab)?.label ?? "Trang chủ"}
              </h2>
              <p className="text-sm text-slate-500 mt-0.5">
                Quản lý toàn bộ ao nuôi, thiết bị IoT, cảnh báo và báo cáo AI
              </p>
            </div>
            <div className="flex items-center gap-3">
              <div className="hidden sm:block text-right">
                <p className="text-sm font-semibold text-slate-700">{currentUser?.fullName || currentUser?.username}</p>
                <p className="text-xs text-slate-500">{currentUser?.role || "ADMIN"}</p>
              </div>
              <button
                type="button"
                onClick={onLogout}
                className="px-3 py-2 rounded-lg border border-slate-300 text-sm font-medium text-slate-700 hover:bg-slate-100"
              >
                Đăng xuất
              </button>
            </div>
          </div>
        </header>
        <main className="flex-1 overflow-auto p-6">
          <div className="max-w-7xl mx-auto">{children}</div>
        </main>
      </div>
    </div>
  );
}
