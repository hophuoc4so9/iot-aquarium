import React, { useState, useEffect } from "react";
import { getUsers, saveUsers } from "../lib/storage";

const ROLES = [
  { value: "ADMIN", label: "Quản trị viên" },
  { value: "FARMER", label: "Người nuôi" },
  { value: "VIEWER", label: "Chỉ xem" },
];

export default function UserManagement() {
  const [users, setUsers] = useState([]);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({ username: "", fullName: "", email: "", role: "FARMER" });

  useEffect(() => {
    setUsers(getUsers());
  }, []);

  const openEdit = (u) => {
    setEditingId(u.id);
    setForm({ username: u.username, fullName: u.fullName || "", email: u.email || "", role: u.role || "FARMER" });
  };

  const handleSave = () => {
    const list = getUsers();
    const idx = list.findIndex((x) => x.id === editingId);
    if (idx >= 0) {
      list[idx] = { ...list[idx], ...form };
    } else {
      list.push({ id: "u-" + Date.now(), ...form });
    }
    saveUsers(list);
    setUsers(list);
    setEditingId(null);
  };

  const handleRoleChange = (userId, newRole) => {
    const list = getUsers().map((u) => (u.id === userId ? { ...u, role: newRole } : u));
    saveUsers(list);
    setUsers(list);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold text-slate-800">Quản lý người dùng & phân quyền</h2>
      <p className="text-sm text-slate-500">
        Phân quyền tài khoản: Quản trị viên, Người nuôi, hoặc Chỉ xem.
      </p>

      <div className="bg-white rounded-xl shadow overflow-hidden">
        <table className="min-w-full divide-y divide-slate-200">
          <thead className="bg-slate-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Tên đăng nhập</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Họ tên</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Email</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase">Vai trò</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-slate-500 uppercase">Thao tác</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-200">
            {users.map((u) => (
              <tr key={u.id} className="hover:bg-slate-50">
                <td className="px-4 py-3 text-sm font-medium text-slate-800">{u.username}</td>
                <td className="px-4 py-3 text-sm text-slate-600">{u.fullName || "—"}</td>
                <td className="px-4 py-3 text-sm text-slate-600">{u.email || "—"}</td>
                <td className="px-4 py-3">
                  <select
                    value={u.role}
                    onChange={(e) => handleRoleChange(u.id, e.target.value)}
                    className="text-sm border rounded px-2 py-1"
                  >
                    {ROLES.map((r) => (
                      <option key={r.value} value={r.value}>{r.label}</option>
                    ))}
                  </select>
                </td>
                <td className="px-4 py-3 text-right">
                  <button onClick={() => openEdit(u)} className="text-blue-600 hover:underline text-sm">Sửa</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editingId && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl shadow-lg p-6 w-full max-w-md">
            <h3 className="text-lg font-medium mb-4">Sửa người dùng</h3>
            <div className="space-y-3">
              <div>
                <label className="block text-xs text-slate-500 mb-1">Tên đăng nhập</label>
                <input
                  type="text"
                  value={form.username}
                  onChange={(e) => setForm({ ...form, username: e.target.value })}
                  className="w-full p-2 border rounded"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">Họ tên</label>
                <input
                  type="text"
                  value={form.fullName}
                  onChange={(e) => setForm({ ...form, fullName: e.target.value })}
                  className="w-full p-2 border rounded"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">Email</label>
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  className="w-full p-2 border rounded"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-500 mb-1">Vai trò</label>
                <select
                  value={form.role}
                  onChange={(e) => setForm({ ...form, role: e.target.value })}
                  className="w-full p-2 border rounded"
                >
                  {ROLES.map((r) => (
                    <option key={r.value} value={r.value}>{r.label}</option>
                  ))}
                </select>
              </div>
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button onClick={() => setEditingId(null)} className="px-3 py-2 rounded border">Đóng</button>
              <button onClick={handleSave} className="px-3 py-2 rounded bg-blue-600 text-white">Lưu</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
