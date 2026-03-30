import React from "react";

export default function Toast({ message, type = "info" }) {
  if (!message) return null;
  const color =
    type === "error"
      ? "bg-rose-500"
      : type === "warn"
      ? "bg-amber-500"
      : "bg-sky-500";
  return (
    <div
      className={`fixed right-6 bottom-6 text-white px-4 py-2 rounded shadow-lg ${color}`}
    >
      {message}
    </div>
  );
}
