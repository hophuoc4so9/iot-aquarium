import React, { useState } from "react";

export default function LoginPage({ onLogin, loading }) {
  const [username, setUsername] = useState("admin");
  const [password, setPassword] = useState("123456");
  const [error, setError] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    try {
      await onLogin(username.trim(), password);
    } catch (err) {
      setError(err?.message || "Đăng nhập thất bại");
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-cyan-100 via-white to-emerald-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md rounded-2xl bg-white/95 shadow-2xl border border-white p-7">
        <div className="text-center mb-6">
          <div className="text-5xl mb-2">🐠</div>
          <h1 className="text-2xl font-bold text-slate-800">Smart Aquarium Admin</h1>
          <p className="text-sm text-slate-500 mt-1">Đăng nhập để quản trị hệ thống ao nuôi</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Tài khoản</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full px-3 py-2.5 rounded-lg border border-slate-300 focus:outline-none focus:ring-2 focus:ring-cyan-500"
              placeholder="Nhập tài khoản"
              autoComplete="username"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Mật khẩu</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2.5 rounded-lg border border-slate-300 focus:outline-none focus:ring-2 focus:ring-cyan-500"
              placeholder="Nhập mật khẩu"
              autoComplete="current-password"
              required
            />
          </div>

          {error ? <p className="text-sm text-rose-600">{error}</p> : null}

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 rounded-lg bg-cyan-600 text-white font-semibold hover:bg-cyan-700 disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {loading ? "Đang đăng nhập..." : "Đăng nhập"}
          </button>
        </form>
      </div>
    </div>
  );
}