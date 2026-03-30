import React, { useState, useEffect } from "react";

const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:8080";

export default function ChatHistoryPage() {
  const [sessions, setSessions] = useState([]);
  const [selectedSession, setSelectedSession] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loadingSessions, setLoadingSessions] = useState(false);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadSessions();
  }, []);

  useEffect(() => {
    if (!selectedSession) {
      setMessages([]);
      return;
    }
    loadHistory(selectedSession);
  }, [selectedSession]);

  async function loadSessions() {
    setLoadingSessions(true);
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/api/chat/sessions`);
      if (!res.ok) throw new Error(res.statusText);
      const data = await res.json();
      const list = Array.isArray(data) ? data : [];
      setSessions(list);
      if (!selectedSession && list.length > 0) setSelectedSession(list[0]);
    } catch (e) {
      setError(e.message);
      setSessions([]);
    } finally {
      setLoadingSessions(false);
    }
  }

  async function loadHistory(sessionId) {
    if (!sessionId) return;
    setLoadingMessages(true);
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/api/chat/history?sessionId=${encodeURIComponent(sessionId)}`);
      if (!res.ok) throw new Error(res.statusText);
      const data = await res.json();
      setMessages(Array.isArray(data) ? data : []);
    } catch (e) {
      setError(e.message);
      setMessages([]);
    } finally {
      setLoadingMessages(false);
    }
  }

  return (
    <div className="space-y-4">
      <p className="text-slate-600">
        Lịch sử chat tư vấn từ app-user (Gemini). Chọn phiên để xem nội dung.
      </p>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-2 rounded-lg text-sm">
          {error}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="px-4 py-3 border-b border-slate-200 font-medium text-slate-800">
            Phiên chat
          </div>
          <div className="max-h-80 overflow-y-auto">
            {loadingSessions ? (
              <div className="p-4 text-slate-500 text-sm">Đang tải...</div>
            ) : sessions.length === 0 ? (
              <div className="p-4 text-slate-500 text-sm">Chưa có phiên nào.</div>
            ) : (
              sessions.map((sid) => (
                <button
                  key={sid}
                  type="button"
                  onClick={() => setSelectedSession(sid)}
                  className={`w-full text-left px-4 py-2.5 text-sm border-b border-slate-100 last:border-0 hover:bg-slate-50 ${
                    selectedSession === sid ? "bg-sky-50 text-sky-700 font-medium" : "text-slate-700"
                  }`}
                >
                  {sid}
                </button>
              ))
            )}
          </div>
        </div>

        <div className="md:col-span-2 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
          <div className="px-4 py-3 border-b border-slate-200 font-medium text-slate-800">
            {selectedSession ? `Nội dung: ${selectedSession}` : "Chọn một phiên"}
          </div>
          <div className="flex-1 overflow-y-auto p-4 min-h-[200px] max-h-[400px] space-y-3">
            {!selectedSession ? (
              <p className="text-slate-500 text-sm">Chọn phiên bên trái để xem.</p>
            ) : loadingMessages ? (
              <p className="text-slate-500 text-sm">Đang tải tin nhắn...</p>
            ) : messages.length === 0 ? (
              <p className="text-slate-500 text-sm">Không có tin nhắn.</p>
            ) : (
              messages.map((m) => (
                <div
                  key={m.id ?? m.createdAt}
                  className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}
                >
                  <div
                    className={`max-w-[85%] rounded-lg px-3 py-2 text-sm ${
                      m.role === "user"
                        ? "bg-sky-100 text-sky-900"
                        : "bg-slate-100 text-slate-800"
                    }`}
                  >
                    <span className="font-medium text-xs text-slate-500 mr-2">
                      {m.role === "user" ? "User" : "AI"}
                    </span>
                    {m.content}
                    {m.createdAt && (
                      <div className="text-xs text-slate-400 mt-1">
                        {new Date(m.createdAt).toLocaleString("vi-VN")}
                      </div>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
