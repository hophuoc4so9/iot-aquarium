import React, { useEffect, useMemo, useRef, useState } from "react";

const API_BASE = (import.meta.env.VITE_API_BASE ?? "http://localhost:8080").replace(/\/+$/, "");

const DEFAULTS = {
  deadlineSeconds: 300,
  minClients: 1,
  minSamples: 1,
  epochs: 1,
  samples: 16,
};

function parseJson(text) {
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

function Badge({ text, tone = "slate" }) {
  const tones = {
    slate: "bg-slate-100 text-slate-700",
    blue: "bg-blue-100 text-blue-700",
    green: "bg-emerald-100 text-emerald-700",
    amber: "bg-amber-100 text-amber-700",
    red: "bg-rose-100 text-rose-700",
  };

  return <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold ${tones[tone]}`}>{text}</span>;
}

function Field({ label, value, onChange, placeholder }) {
  return (
    <div>
      <label className="block text-xs font-medium text-slate-500 mb-1.5">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full border border-slate-200 rounded-lg px-3 py-2.5 text-sm
                   focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
      />
    </div>
  );
}

function Section({ title, subtitle, children }) {
  return (
    <section className="bg-white rounded-xl border border-slate-200 shadow-sm p-5 space-y-3">
      <div>
        <h3 className="text-base font-semibold text-slate-800">{title}</h3>
        {subtitle && <p className="text-sm text-slate-500 mt-0.5">{subtitle}</p>}
      </div>
      {children}
    </section>
  );
}

export default function FederatedLearningPage() {
  const [roundId, setRoundId] = useState("");
  const [deviceIdsCsv, setDeviceIdsCsv] = useState("");
  const [deadlineSeconds, setDeadlineSeconds] = useState(String(DEFAULTS.deadlineSeconds));
  const [minClients, setMinClients] = useState(String(DEFAULTS.minClients));
  const [minSamples, setMinSamples] = useState(String(DEFAULTS.minSamples));
  const [epochs, setEpochs] = useState(String(DEFAULTS.epochs));
  const [samples, setSamples] = useState(String(DEFAULTS.samples));
  const [onlineDevices, setOnlineDevices] = useState([]);
  const [onlineDevicesLoading, setOnlineDevicesLoading] = useState(false);
  const [onlineDevicesError, setOnlineDevicesError] = useState("");
  const [onlineWindowSeconds, setOnlineWindowSeconds] = useState(120);
  const hasInitializedOnlineSelectionRef = useRef(false);
  const [statusRoundId, setStatusRoundId] = useState("");

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);
  const [roundData, setRoundData] = useState(null);
  const [reportsData, setReportsData] = useState([]);

  const [latestModel, setLatestModel] = useState(null);
  const [latestModelError, setLatestModelError] = useState("");
  const [latestModelLoading, setLatestModelLoading] = useState(false);
  const [runtimeStatus, setRuntimeStatus] = useState(null);

  const [historyRows, setHistoryRows] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyStatusFilter, setHistoryStatusFilter] = useState("ALL");
  const [historyPage, setHistoryPage] = useState(0);
  const [historySize, setHistorySize] = useState("10");
  const [historyTotalPages, setHistoryTotalPages] = useState(0);
  const [historyTotalItems, setHistoryTotalItems] = useState(0);

  const [aggregateError, setAggregateError] = useState("");
  const [autoRetryEnabled, setAutoRetryEnabled] = useState(false);
  const [autoRetryAttempts, setAutoRetryAttempts] = useState(0);
  const [nowTs, setNowTs] = useState(Date.now());

  const parsedDeviceIds = useMemo(
    () =>
      deviceIdsCsv
        .split(",")
        .map((x) => x.trim())
        .filter(Boolean)
        .map((x) => Number.parseInt(x, 10))
        .filter((n) => Number.isFinite(n)),
    [deviceIdsCsv],
  );

  const onlineDeviceIds = useMemo(
    () =>
      onlineDevices
        .map((x) => Number.parseInt(x.deviceId, 10))
        .filter((x) => Number.isFinite(x) && x > 0),
    [onlineDevices],
  );

  const reportRows = useMemo(() => {
    return reportsData
      .map((r) => {
        const deviceId = Number.parseInt(r.deviceId ?? r.device_id ?? 0, 10);
        const pondId = Number.parseInt(r.pondId ?? r.pond_id ?? 0, 10);
        const loss = Number.parseFloat(r.loss ?? NaN);
        const sampleCount = Number.parseInt(r.sampleCount ?? r.samples ?? 0, 10);
        return {
          deviceId: Number.isFinite(deviceId) ? deviceId : 0,
          pondId: Number.isFinite(pondId) ? pondId : 0,
          loss: Number.isFinite(loss) ? loss : null,
          sampleCount: Number.isFinite(sampleCount) ? sampleCount : 0,
          modelVersion: r.modelVersion ?? r.model_version ?? null,
          success: r.success,
        };
      })
      .filter((x) => x.deviceId > 0 || x.pondId > 0);
  }, [reportsData]);

  const currentRoundDeviceIds = useMemo(() => {
    const fromRound = Array.isArray(roundData?.targetDeviceIds) ? roundData.targetDeviceIds : [];
    const ids = fromRound.length > 0 ? fromRound : parsedDeviceIds;
    return ids
      .map((x) => Number.parseInt(x, 10))
      .filter((x) => Number.isFinite(x) && x > 0)
      .sort((a, b) => a - b);
  }, [parsedDeviceIds, roundData?.targetDeviceIds]);

  const reportedDeviceIds = useMemo(() => {
    return reportRows
      .map((row) => row.deviceId)
      .filter((deviceId) => Number.isFinite(deviceId) && deviceId > 0)
      .sort((a, b) => a - b);
  }, [reportRows]);

  const pendingDeviceIds = useMemo(() => {
    const reportedSet = new Set(reportedDeviceIds);
    return currentRoundDeviceIds.filter((deviceId) => !reportedSet.has(deviceId));
  }, [currentRoundDeviceIds, reportedDeviceIds]);

  const allSelectedReported = currentRoundDeviceIds.length > 0 && pendingDeviceIds.length === 0;

  const deadlineReached = useMemo(() => {
    const deadlineAt = roundData?.deadlineAt || result?.data?.deadlineAt;
    if (!deadlineAt) return false;
    const deadlineMs = Date.parse(deadlineAt);
    if (!Number.isFinite(deadlineMs)) return false;
    return nowTs >= deadlineMs;
  }, [nowTs, result?.data?.deadlineAt, roundData?.deadlineAt]);

  const canAggregate = allSelectedReported || deadlineReached;
  const aggregateGateLabel = canAggregate
    ? (allSelectedReported ? "Đã đủ device gửi" : "Đã hết thời gian")
    : pendingDeviceIds.length > 0
      ? `Còn ${pendingDeviceIds.length} device chưa gửi`
      : "Đang chờ report hoặc deadline";

  const systemLoss = useMemo(() => {
    const valid = reportRows.filter((x) => x.loss !== null && x.sampleCount > 0);
    if (valid.length === 0) return null;
    const weightedSum = valid.reduce((acc, x) => acc + x.loss * x.sampleCount, 0);
    const sampleSum = valid.reduce((acc, x) => acc + x.sampleCount, 0);
    if (sampleSum <= 0) return null;
    return weightedSum / sampleSum;
  }, [reportRows]);

  const selectedDeviceRows = useMemo(() => {
    const selectedSet = new Set(currentRoundDeviceIds);
    return onlineDevices
      .filter((device) => selectedSet.has(device.deviceId))
      .map((device) => ({
        ...device,
        reported: reportedDeviceIds.includes(device.deviceId),
      }));
  }, [currentRoundDeviceIds, onlineDevices, reportedDeviceIds]);

  const suggestedRoundId = useMemo(() => {
    const modelRound = Number.parseInt(String(latestModel?.roundId ?? "0"), 10);
    const typedRound = Number.parseInt(roundId, 10);
    const statusRound = Number.parseInt(statusRoundId, 10);
    const base = Math.max(
      Number.isFinite(modelRound) ? modelRound : 0,
      Number.isFinite(typedRound) ? typedRound : 0,
      Number.isFinite(statusRound) ? statusRound : 0,
    );
    return base + 1;
  }, [latestModel?.roundId, roundId, statusRoundId]);

  function summarizeRoundStatus(data) {
    if (!data || typeof data !== "object") return { text: "Không rõ", tone: "slate" };

    const state = String(data.status || "").toUpperCase();
    if (state === "AGGREGATED") return { text: "Đã aggregate", tone: "green" };
    if (state === "COLLECTING" || state === "STARTED") return { text: "Đang thu update", tone: "blue" };

    const pending = Number.parseInt(data.pendingUpdates ?? data.pending ?? 0, 10);
    const eligible = Number.parseInt(data.eligibleUpdates ?? data.eligible ?? 0, 10);
    if (Number.isFinite(pending) && Number.isFinite(eligible)) {
      if (pending === 0) return { text: "Chưa có update", tone: "amber" };
      if (eligible >= 1) return { text: "Sẵn sàng aggregate", tone: "green" };
      return { text: "Đang chờ đủ điều kiện", tone: "amber" };
    }

    return { text: "Đang theo dõi", tone: "slate" };
  }

  async function runRequest(label, url, options = {}) {
    setBusy(true);
    setError("");
    setResult(null);

    try {
      const res = await fetch(url, options);
      const text = await res.text();
      const json = parseJson(text);

      if (label === "Round status" && res.status === 404) {
        setRoundData(null);
        setResult({ label, data: json });
        return json;
      }

      if (!res.ok) {
        throw new Error(json.message || json.detail || json.error || `${label} thất bại (${res.status})`);
      }
      setResult({ label, data: json });
      if (label === "Round status") {
        setRoundData(json);
      }
      if (label === "Aggregate round") {
        loadLatestModel();
        loadRoundReports(Number.parseInt(roundId, 10));
      }
      return json;
    } catch (e) {
      setError(e?.message || String(e));
      return null;
    } finally {
      setBusy(false);
    }
  }
  async function tryAggregate(targetRoundId, isAutoRetry = false) {
    setBusy(true);
    setAggregateError("");
    setResult(null);

    try {
      const res = await fetch(`${API_BASE}/api/fl/rounds/${targetRoundId}/aggregate`, {
        method: "POST",
      });
      const text = await res.text();
      const json = parseJson(text);

      if (Boolean(json.success) === false) {
        const errorMsg = json.error || json.detail || json.message || "Chưa đủ điều kiện để aggregate";
        setAggregateError(errorMsg);
        setResult({ label: "Aggregate round", data: json });
        return false;
      }

      if (!res.ok) {
        throw new Error(json.message || json.detail || json.error || `Aggregate thất bại (${res.status})`);
      }

      setAggregateError("");
      setResult({ label: "Aggregate round", data: json });
      setAutoRetryAttempts(0);
      loadLatestModel();
      loadRoundReports(targetRoundId);
      return true;
    } catch (e) {
      setError(e?.message || String(e));
      return false;
    } finally {
      setBusy(false);
    }
  }
  async function loadRoundReports(targetRoundId) {
    if (!Number.isFinite(targetRoundId) || targetRoundId <= 0) return;
    try {
      const res = await fetch(`${API_BASE}/api/fl/rounds/${targetRoundId}/reports`);
      const text = await res.text();
      const json = parseJson(text);
      if (!res.ok) return;
      const reports = Array.isArray(json.reports) ? json.reports : [];
      setReportsData(reports);
    } catch {
      // Keep current reports if request fails.
    }
  }

  async function loadLatestModel() {
    setLatestModelLoading(true);
    setLatestModelError("");

    try {
      const res = await fetch(`${API_BASE}/api/fl/models/latest`);
      const text = await res.text();
      const json = parseJson(text);
      if (!res.ok) {
        throw new Error(json.message || json.detail || "Chưa có model global active");
      }
      setLatestModel(json);

      const modelRound = Number.parseInt(String(json?.roundId ?? "0"), 10);
      if (Number.isFinite(modelRound) && modelRound >= 0) {
        if (!roundId.trim()) {
          setRoundId(String(modelRound + 1));
        }
        if (!statusRoundId.trim()) {
          setStatusRoundId(String(modelRound + 1));
        }
      }
    } catch (e) {
      setLatestModel(null);
      setLatestModelError(e?.message || String(e));
    } finally {
      setLatestModelLoading(false);
    }
  }

  async function loadRuntimeStatus() {
    try {
      const res = await fetch(`${API_BASE}/api/fl/runtime`);
      const text = await res.text();
      const json = parseJson(text);
      if (!res.ok) return;
      setRuntimeStatus(json);
    } catch {
      // Keep last known runtime status.
    }
  }

  async function loadOnlineDevices() {
    setOnlineDevicesLoading(true);
    setOnlineDevicesError("");
    try {
      const res = await fetch(`${API_BASE}/api/fl/devices/online`);
      const text = await res.text();
      const json = parseJson(text);
      if (!res.ok) {
        throw new Error(json.message || json.detail || "Không tải được danh sách device online");
      }

      const items = Array.isArray(json.items) ? json.items : [];
      const normalized = items
        .map((it) => ({
          deviceId: Number.parseInt(it.deviceId, 10),
          pondId: Number.parseInt(it.pondId, 10),
          pondName: String(it.pondName || ""),
          lastTelemetryAt: it.lastTelemetryAt,
          secondsSinceLastTelemetry: Number.parseInt(it.secondsSinceLastTelemetry, 10),
        }))
        .filter((it) => Number.isFinite(it.deviceId) && it.deviceId > 0)
        .sort((a, b) => a.deviceId - b.deviceId);

      setOnlineWindowSeconds(Number.parseInt(json.onlineWindowSeconds, 10) || 120);
      setOnlineDevices(normalized);
      setDeviceIdsCsv((prev) => {
        const available = new Set(normalized.map((x) => x.deviceId));
        if (!hasInitializedOnlineSelectionRef.current) {
          hasInitializedOnlineSelectionRef.current = true;
          return normalized.map((x) => x.deviceId).join(",");
        }

        const previousSelected = prev
          .split(",")
          .map((x) => Number.parseInt(x.trim(), 10))
          .filter((x) => Number.isFinite(x) && available.has(x));
        return previousSelected.join(",");
      });
    } catch (e) {
      setOnlineDevicesError(e?.message || String(e));
      setOnlineDevices([]);
    } finally {
      setOnlineDevicesLoading(false);
    }
  }

  function setSelectedDeviceEnabled(deviceId, enabled) {
    const current = new Set(parsedDeviceIds);
    if (enabled) {
      current.add(deviceId);
    } else {
      current.delete(deviceId);
    }
    setDeviceIdsCsv(Array.from(current).sort((a, b) => a - b).join(","));
  }

  function selectAllOnlineDevices() {
    setDeviceIdsCsv(onlineDeviceIds.join(","));
  }

  function clearSelectedDevices() {
    setDeviceIdsCsv("");
  }

  function formatLastSeen(seconds) {
    const value = Number.parseInt(seconds, 10);
    if (!Number.isFinite(value) || value < 0) {
      return "không rõ";
    }
    if (value < 60) {
      return `${value}s trước`;
    }
    const minutes = Math.floor(value / 60);
    return `${minutes}m trước`;
  }

  async function loadRoundHistory(pageOverride = historyPage) {
    const parsedSize = Number.parseInt(historySize, 10);
    const safeSize = Number.isFinite(parsedSize) ? Math.max(1, Math.min(100, parsedSize)) : 10;
    const safePage = Math.max(0, pageOverride);

    setHistoryLoading(true);
    try {
      const params = new URLSearchParams({
        status: historyStatusFilter,
        page: String(safePage),
        size: String(safeSize),
      });
      const res = await fetch(`${API_BASE}/api/fl/rounds/history?${params.toString()}`);
      const text = await res.text();
      const json = parseJson(text);
      if (!res.ok) return;

      setHistoryRows(Array.isArray(json.items) ? json.items : []);
      setHistoryPage(Number.parseInt(String(json.page ?? safePage), 10) || 0);
      setHistoryTotalPages(Number.parseInt(String(json.totalPages ?? 0), 10) || 0);
      setHistoryTotalItems(Number.parseInt(String(json.totalItems ?? 0), 10) || 0);
    } catch {
      // Keep previous history data when request fails.
    } finally {
      setHistoryLoading(false);
    }
  }

  useEffect(() => {
    loadLatestModel();
    loadRuntimeStatus();
    loadOnlineDevices();
    loadRoundHistory(0);
  }, []);

  useEffect(() => {
    loadRoundHistory(0);
  }, [historyStatusFilter, historySize]);

  useEffect(() => {
    const id = Number.parseInt(statusRoundId, 10);
    if (Number.isFinite(id) && id > 0) {
      loadRoundReports(id);
    }
  }, [statusRoundId]);

  useEffect(() => {
    if (!autoRetryEnabled) return;
    const retryIntervalMs = 15000;
    const maxAttempts = 20;

    const timer = setInterval(async () => {
      if (busy || !aggregateError) return;
      if (autoRetryAttempts >= maxAttempts) {
        setAutoRetryEnabled(false);
        setError(`Auto-retry đã vượt quá ${maxAttempts} lần. Dừng thử lại.`);
        return;
      }

      const target = Number.parseInt(roundId, 10);
      if (!Number.isFinite(target) || target <= 0) return;

      const success = await tryAggregate(target, true);
      if (success) {
        setAutoRetryEnabled(false);
      } else {
        setAutoRetryAttempts((prev) => prev + 1);
      }
    }, retryIntervalMs);

    return () => clearInterval(timer);
  }, [autoRetryEnabled, aggregateError, busy, autoRetryAttempts, roundId]);

  useEffect(() => {
    const intervalMs = 30000;

    const timer = setInterval(async () => {
      if (busy) return;

      await loadLatestModel();
      await loadRuntimeStatus();
      await loadOnlineDevices();
      await loadRoundHistory();

      const target = Number.parseInt(statusRoundId || roundId, 10);
      if (Number.isFinite(target) && target > 0) {
        setStatusRoundId(String(target));
        await runRequest("Round status", `${API_BASE}/api/fl/rounds/${target}`);
        await loadRoundReports(target);
      }
    }, intervalMs);

    return () => clearInterval(timer);
  }, [busy, roundId, statusRoundId]);

  useEffect(() => {
    const timer = setInterval(() => setNowTs(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  async function startRound() {
    const parsedRoundId = Number.parseInt(roundId, 10);
    const autoRoundId = Number.isFinite(parsedRoundId) && parsedRoundId > 0 ? parsedRoundId : suggestedRoundId;
    const parsedDeadlineSeconds = Number.parseInt(deadlineSeconds, 10);
    const parsedMinClients = Number.parseInt(minClients, 10);
    const parsedMinSamples = Number.parseInt(minSamples, 10);
    const parsedEpochs = Number.parseInt(epochs, 10);
    const parsedSamples = Number.parseInt(samples, 10);

    if (!Number.isFinite(parsedDeadlineSeconds) || parsedDeadlineSeconds < 30) {
      setError("deadlineSeconds phải >= 30");
      return null;
    }
    if (!Number.isFinite(parsedMinClients) || parsedMinClients < 1) {
      setError("minClients phải >= 1");
      return null;
    }
    if (!Number.isFinite(parsedMinSamples) || parsedMinSamples < 1) {
      setError("minSamples phải >= 1");
      return null;
    }
    if (!Number.isFinite(parsedEpochs) || parsedEpochs < 1) {
      setError("epochs phải >= 1");
      return null;
    }
    if (!Number.isFinite(parsedSamples) || parsedSamples < 1) {
      setError("samples phải >= 1");
      return null;
    }

    const body = {
      roundId: autoRoundId,
      deadlineSeconds: parsedDeadlineSeconds,
      minClients: parsedMinClients,
      minSamples: parsedMinSamples,
      epochs: parsedEpochs,
      samples: parsedSamples,
      deviceIds: parsedDeviceIds,
    };

    if (!Array.isArray(parsedDeviceIds) || parsedDeviceIds.length === 0) {
      setError("Hãy chọn ít nhất 1 device online trước khi start round.");
      return null;
    }

    setBusy(true);
    setError("");
    setResult(null);

    try {
      const res = await fetch(`${API_BASE}/api/fl/rounds/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const text = await res.text();
      const json = parseJson(text);

      if (!res.ok) {
        const msg = json?.error || json?.message || json?.detail || `Start round thất bại (${res.status})`;
        if (String(msg).includes("Round already exists")) {
          const next = autoRoundId + 1;
          setRoundId(String(next));
          setStatusRoundId(String(next));
          setError(`Round ${autoRoundId} đã tồn tại. Đã tự gợi ý round ${next}.`);
          return null;
        }
        throw new Error(msg);
      }

      setResult({ label: "Start round", data: json });
      setRoundData(json);
      const startedRoundId = Number.parseInt(String(json?.roundId ?? "0"), 10);
      if (Number.isFinite(startedRoundId) && startedRoundId > 0) {
        setRoundId(String(startedRoundId));
        setStatusRoundId(String(startedRoundId));
      }
      setAggregateError("");
      return json;
    } catch (e) {
      setError(e?.message || String(e));
      return null;
    } finally {
      setBusy(false);
    }
  }

  function aggregateRound() {
    const target = Number.parseInt(roundId, 10);
    if (!Number.isFinite(target) || target <= 0) {
      setError("Round ID không hợp lệ");
      return;
    }
    if (!canAggregate) {
      setError("Chưa đủ report hoặc chưa tới deadline để aggregate");
      return;
    }
    return tryAggregate(target, false);
  }

  function checkRoundStatus() {
    const target = Number.parseInt(statusRoundId, 10);
    loadRoundReports(target);
    return runRequest("Round status", `${API_BASE}/api/fl/rounds/${target}`);
  }

  const statusSummary = summarizeRoundStatus(result?.label === "Round status" ? result?.data : null);

  return (
    <div className="space-y-5">
      <Section
        title="Federated Learning Orchestration"
        subtitle="Trang vận hành dành cho quản lý hệ thống: Start round tự động, theo dõi thông số/loss theo ao và toàn hệ thống."
      >
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3 text-sm">
          <div className="rounded-lg border border-slate-200 p-3 bg-slate-50">
            <div className="text-xs text-slate-500 uppercase">Model version</div>
            <div className="font-semibold text-slate-800">{latestModel?.version ?? "—"}</div>
          </div>
          <div className="rounded-lg border border-slate-200 p-3 bg-slate-50">
            <div className="text-xs text-slate-500 uppercase">Round hiện tại</div>
            <div className="font-semibold text-slate-800">{latestModel?.roundId ?? "—"}</div>
          </div>
          <div className="rounded-lg border border-slate-200 p-3 bg-slate-50">
            <div className="text-xs text-slate-500 uppercase">Model status</div>
            <div className="font-semibold text-slate-800">{latestModel?.status ?? "—"}</div>
          </div>
          <div className="rounded-lg border border-slate-200 p-3 bg-slate-50">
            <div className="text-xs text-slate-500 uppercase">Round status</div>
            <div className="mt-1">
              <Badge text={statusSummary.text} tone={statusSummary.tone} />
            </div>
          </div>
          <div className="rounded-lg border border-slate-200 p-3 bg-slate-50">
            <div className="text-xs text-slate-500 uppercase">System loss</div>
            <div className="font-semibold text-slate-800">{systemLoss === null ? "—" : systemLoss.toFixed(6)}</div>
          </div>
          <div className="rounded-lg border border-slate-200 p-3 bg-slate-50">
            <div className="text-xs text-slate-500 uppercase">Orchestration</div>
            <div className="mt-1">
              <Badge
                text={runtimeStatus?.autoStartEnabled ? "Backend auto-run ON" : "Backend auto-run OFF"}
                tone={runtimeStatus?.autoStartEnabled ? "green" : "amber"}
              />
            </div>
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          
          <button
            disabled={busy}
            onClick={() => {
              loadLatestModel();
              loadRuntimeStatus();
              loadOnlineDevices();
              loadRoundHistory(0);
              const target = Number.parseInt(statusRoundId || roundId, 10);
              if (Number.isFinite(target) && target > 0) {
                loadRoundReports(target);
                runRequest("Round status", `${API_BASE}/api/fl/rounds/${target}`);
              }
            }}
            className="px-3 py-2 rounded-lg border border-slate-300 text-sm hover:bg-slate-50 disabled:opacity-50"
          >
            Làm mới 
          </button>
          {latestModelError && <span className="text-sm text-amber-700">{latestModelError}</span>}
        </div>
      </Section>

      <Section title="1) Start Round" subtitle="Khởi tạo vòng học mới cho các thiết bị được chọn.">
        <div className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-[1fr_auto] gap-2 items-end max-w-2xl">
            <Field label="Round ID" value={roundId} onChange={setRoundId} placeholder={`Tự động: ${suggestedRoundId}`} />
            <button
              type="button"
              onClick={() => {
                setRoundId(String(suggestedRoundId));
                setStatusRoundId(String(suggestedRoundId));
              }}
              className="h-[42px] px-3 rounded-lg border border-slate-300 text-sm hover:bg-slate-50"
            >
              Dùng {suggestedRoundId}
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-3">
            <Field label="Deadline (giây)" value={deadlineSeconds} onChange={setDeadlineSeconds} placeholder="300" />
            <Field label="Min clients" value={minClients} onChange={setMinClients} placeholder="1" />
            <Field label="Min samples" value={minSamples} onChange={setMinSamples} placeholder="1" />
            <Field label="Epochs" value={epochs} onChange={setEpochs} placeholder="1" />
            <Field label="Samples" value={samples} onChange={setSamples} placeholder="16" />
          </div>

          <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 space-y-4 w-full">
            <div className="flex items-start justify-between gap-3 flex-wrap">
              <div>
                <div className="text-sm font-semibold text-slate-800">Thiết bị tham gia round</div>
                <div className="text-xs text-slate-500 mt-1">
                  Device ID là ID thiết bị. Pond ID là ID ao. Simulator mặc định dùng 1,2,3; ESP32-S3 thật của bạn là 5.
                </div>
              </div>
              <div className="flex items-center gap-2 flex-wrap">
                <button
                  type="button"
                  onClick={selectAllOnlineDevices}
                  disabled={onlineDevicesLoading || onlineDeviceIds.length === 0}
                  className="px-2.5 py-1.5 rounded border border-slate-300 text-xs hover:bg-slate-50 disabled:opacity-50"
                >
                  Bật tất cả
                </button>
                <button
                  type="button"
                  onClick={clearSelectedDevices}
                  disabled={onlineDevicesLoading || parsedDeviceIds.length === 0}
                  className="px-2.5 py-1.5 rounded border border-slate-300 text-xs hover:bg-slate-50 disabled:opacity-50"
                >
                  Tắt tất cả
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
              <div className="rounded-lg border border-slate-200 bg-white px-3 py-2">
                <div className="text-slate-500 uppercase">Selected</div>
                <div className="mt-1 font-semibold text-slate-800">{currentRoundDeviceIds.length} device(s)</div>
              </div>
              <div className="rounded-lg border border-slate-200 bg-white px-3 py-2">
                <div className="text-slate-500 uppercase">Reported</div>
                <div className="mt-1 font-semibold text-emerald-700">{reportedDeviceIds.length} device(s)</div>
              </div>
              <div className="rounded-lg border border-slate-200 bg-white px-3 py-2">
                <div className="text-slate-500 uppercase">Pending</div>
                <div className="mt-1 font-semibold text-amber-700">{pendingDeviceIds.length} device(s)</div>
              </div>
            </div>

            <div className="text-xs text-slate-500">
              Mặc định chọn tất cả device online trong {onlineWindowSeconds}s gần nhất.
            </div>

            {onlineDevicesLoading ? (
              <div className="text-sm text-slate-500">Đang tải danh sách device online...</div>
            ) : onlineDevices.length === 0 ? (
              <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
                Chưa thấy device online. Hãy bật simulator hoặc thiết bị thật rồi refresh.
              </div>
            ) : (
              <div className="overflow-hidden rounded-xl border border-slate-200 bg-white w-full">
                <div className="max-h-[420px] overflow-auto">
                  <table className="min-w-full text-sm">
                    <thead className="sticky top-0 bg-slate-100 text-slate-600 z-10">
                      <tr>
                        <th className="text-left px-3 py-2 w-12">Chọn</th>
                        <th className="text-left px-3 py-2">Device ID</th>
                        <th className="text-left px-3 py-2">Pond</th>
                        <th className="text-left px-3 py-2">Pond name</th>
                        <th className="text-right px-3 py-2">Last seen</th>
                      </tr>
                    </thead>
                    <tbody>
                      {onlineDevices.map((dev) => {
                        const checked = parsedDeviceIds.includes(dev.deviceId);
                        return (
                          <tr key={`online-${dev.deviceId}`} className="border-t border-slate-100 hover:bg-slate-50">
                            <td className="px-3 py-2">
                              <input
                                type="checkbox"
                                checked={checked}
                                onChange={(e) => setSelectedDeviceEnabled(dev.deviceId, e.target.checked)}
                              />
                            </td>
                            <td className="px-3 py-2 font-medium text-slate-800">{dev.deviceId}</td>
                            <td className="px-3 py-2 text-slate-700">{dev.pondId || "?"}</td>
                            <td className="px-3 py-2 text-slate-700">{dev.pondName || "—"}</td>
                            <td className="px-3 py-2 text-right text-slate-500">{formatLastSeen(dev.secondsSinceLastTelemetry)}</td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {onlineDevicesError && <div className="text-xs text-rose-700">{onlineDevicesError}</div>}
            <div className="flex items-center justify-between gap-3 text-xs text-slate-500">
              <span>Đã chọn: {parsedDeviceIds.length} device(s)</span>
              <span>Tự đồng bộ theo danh sách device online hiện tại</span>
            </div>
            <Field label="Device IDs (CSV)" value={deviceIdsCsv} onChange={setDeviceIdsCsv} placeholder="1,2,3" />

            <div className="rounded-xl border border-slate-200 bg-white overflow-hidden">
              <div className="px-3 py-2 border-b border-slate-200 bg-slate-50">
                <div className="text-sm font-semibold text-slate-800">Thiết bị đang gửi trong round</div>
                <div className="text-xs text-slate-500">
                  Chỉ khi tất cả device đã gửi hoặc deadline hết thì mới enable Aggregate.
                </div>
              </div>
              {selectedDeviceRows.length === 0 ? (
                <div className="px-3 py-3 text-sm text-slate-500">Chưa có device nào trong round này.</div>
              ) : (
                <div className="max-h-64 overflow-auto">
                  <table className="min-w-full text-sm">
                    <thead className="bg-slate-50 text-slate-600">
                      <tr>
                        <th className="text-left px-3 py-2">Device</th>
                        <th className="text-left px-3 py-2">Pond</th>
                        <th className="text-right px-3 py-2">Last seen</th>
                        <th className="text-left px-3 py-2">State</th>
                      </tr>
                    </thead>
                    <tbody>
                      {selectedDeviceRows.map((dev) => (
                        <tr key={`selected-${dev.deviceId}`} className="border-t border-slate-100">
                          <td className="px-3 py-2 font-medium text-slate-800">{dev.deviceId}</td>
                          <td className="px-3 py-2 text-slate-700">{dev.pondId || "?"}</td>
                          <td className="px-3 py-2 text-right text-slate-500">{formatLastSeen(dev.secondsSinceLastTelemetry)}</td>
                          <td className="px-3 py-2">{dev.reported ? <Badge text="Reported" tone="green" /> : <Badge text="Pending" tone="amber" />}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>

          <button
            disabled={busy}
            onClick={startRound}
            className="w-full px-4 py-3 rounded-xl bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50"
          >
            Start Round
          </button>

          
        </div>
      </Section>

        {/* <Section title="2) Upload Local Update" subtitle="Bước này tự động từ IoT (không nhập tay).">
          <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-800">
            Thiết bị ESP32 sau khi train local sẽ tự gửi update lên backend qua MQTT. Quản lý không cần upload thủ công.
          </div>
          <div className="rounded-lg bg-slate-50 border border-slate-200 p-3 text-xs text-slate-600 leading-5">
            Ý nghĩa: hệ thống giảm sai sót vận hành, tránh nhập nhầm weights/shape/loss trong giao diện quản lý.
          </div>
        </Section> */}

        <Section title="2) Aggregate Round" subtitle="Gộp các update đã thu thành model global mới.">
          <div className="space-y-3">
            <button
              disabled={busy || !canAggregate}
              onClick={aggregateRound}
              className="w-full px-4 py-2.5 rounded-lg bg-violet-600 text-white text-sm font-medium hover:bg-violet-700 disabled:opacity-50"
            >
              {canAggregate ? `Aggregate Round #${roundId}` : `Chờ report / deadline để aggregate #${roundId}`}
            </button>
            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs text-slate-600 leading-5">
              Trạng thái: <span className="font-semibold text-slate-800">{aggregateGateLabel}</span>.{' '}
              {deadlineReached ? "Deadline đã tới, có thể aggregate ngay." : allSelectedReported ? "Tất cả device đã báo cáo." : `Còn pending: ${pendingDeviceIds.join(", ") || "—"}`}
            </div>
            {aggregateError && (
              <div className="rounded-lg border border-amber-200 bg-amber-50 p-3">
                <div className="text-sm text-amber-900 font-semibold mb-1.5">Chưa sẵn sàng aggregate:</div>
                <div className="text-xs text-amber-800 mb-2">{aggregateError}</div>
                <label className="flex items-center gap-2 text-xs text-amber-900">
                  <input
                    type="checkbox"
                    checked={autoRetryEnabled}
                    onChange={(e) => {
                      setAutoRetryEnabled(e.target.checked);
                      if (e.target.checked) {
                        setAutoRetryAttempts(0);
                      }
                    }}
                  />
                  Thử lại tự động mỗi 15 giây {autoRetryAttempts > 0 && `(lần ${autoRetryAttempts})`}
                </label>
              </div>
            )}
          </div>
          
        </Section>

      <Section title="Round Status" subtitle="Theo dõi tiến độ vòng học trước khi aggregate.">
        <div className="grid grid-cols-1 md:grid-cols-[1fr_auto] gap-3 items-end">
          <Field label="Round ID cần kiểm tra" value={statusRoundId} onChange={setStatusRoundId} placeholder="201" />
          <button
            disabled={busy}
            onClick={checkRoundStatus}
            className="px-4 py-2.5 rounded-lg border border-slate-300 text-sm hover:bg-slate-50 disabled:opacity-50"
          >
            Refresh
          </button>
        </div>
        <div className="rounded-lg bg-slate-50 border border-slate-200 p-3 text-xs text-slate-600 leading-5">
          Dùng để xem round đang ở trạng thái nào (chưa có update, đang thu update, hay đã sẵn sàng aggregate).
        </div>
        <div className="rounded-xl border border-slate-200 overflow-hidden">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="text-left px-3 py-2">Device</th>
                <th className="text-left px-3 py-2">Pond</th>
                <th className="text-right px-3 py-2">Samples</th>
                <th className="text-right px-3 py-2">Loss</th>
                <th className="text-left px-3 py-2">State</th>
              </tr>
            </thead>
            <tbody>
              {currentRoundDeviceIds.length === 0 ? (
                <tr>
                  <td className="px-3 py-3 text-slate-500" colSpan={5}>Chưa có device nào trong round hiện tại.</td>
                </tr>
              ) : (
                currentRoundDeviceIds.map((deviceId) => {
                  const row = reportRows.find((r) => r.deviceId === deviceId);
                  return (
                    <tr key={`status-${deviceId}`} className="border-t border-slate-100">
                      <td className="px-3 py-2 font-medium text-slate-800">{deviceId}</td>
                      <td className="px-3 py-2 text-slate-700">{row?.pondId ?? "—"}</td>
                      <td className="px-3 py-2 text-right">{row?.sampleCount ?? 0}</td>
                      <td className="px-3 py-2 text-right">{row?.loss === null || row?.loss === undefined ? "—" : row.loss.toFixed(6)}</td>
                      <td className="px-3 py-2">{row ? <Badge text="Reported" tone="green" /> : <Badge text="Pending" tone="amber" />}</td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </Section>

      <Section title="Danh sách thông số & loss theo ao" subtitle="Dữ liệu tổng hợp từ report của thiết bị trong round đang chọn.">
        {reportRows.length === 0 ? (
          <div className="text-sm text-slate-500">Chưa có report cho round này.</div>
        ) : (
          <div className="overflow-auto border border-slate-200 rounded-lg">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-50 text-slate-600">
                <tr>
                  <th className="text-left px-3 py-2">Pond</th>
                  <th className="text-left px-3 py-2">Device</th>
                  <th className="text-right px-3 py-2">Samples</th>
                  <th className="text-right px-3 py-2">Loss</th>
                  <th className="text-right px-3 py-2">Model Version</th>
                  <th className="text-left px-3 py-2">Success</th>
                </tr>
              </thead>
              <tbody>
                {reportRows.map((r, idx) => (
                  <tr key={`${r.pondId}-${r.deviceId}-${idx}`} className="border-t border-slate-100">
                    <td className="px-3 py-2">{r.pondId || "—"}</td>
                    <td className="px-3 py-2">{r.deviceId || "—"}</td>
                    <td className="px-3 py-2 text-right">{r.sampleCount}</td>
                    <td className="px-3 py-2 text-right">{r.loss === null ? "—" : r.loss.toFixed(6)}</td>
                    <td className="px-3 py-2 text-right">{r.modelVersion ?? "—"}</td>
                    <td className="px-3 py-2">{r.success === true ? <Badge text="OK" tone="green" /> : <Badge text="N/A" tone="amber" />}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <div className="text-xs text-slate-600 bg-slate-50 border border-slate-200 rounded-lg p-3">
          Loss toàn hệ thống được tính theo weighted average trên sampleCount của các ao có loss hợp lệ.
        </div>
      </Section>

      <Section title="Lịch sử FL Rounds" subtitle="Theo dõi các vòng đã chạy với lọc trạng thái và phân trang.">
        <div className="grid grid-cols-1 md:grid-cols-[180px_140px_auto] gap-3 items-end">
          <div>
            <label className="block text-xs font-medium text-slate-500 mb-1.5">Status</label>
            <select
              value={historyStatusFilter}
              onChange={(e) => setHistoryStatusFilter(e.target.value)}
              className="w-full border border-slate-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
            >
              <option value="ALL">ALL</option>
              <option value="OPEN">OPEN</option>
              <option value="AGGREGATED">AGGREGATED</option>
              <option value="FAILED">FAILED</option>
            </select>
          </div>
          <Field label="Page size" value={historySize} onChange={setHistorySize} placeholder="10" />
          <div className="flex gap-2 md:justify-end">
            <button
              type="button"
              onClick={() => loadRoundHistory(0)}
              disabled={historyLoading}
              className="px-3 py-2 rounded-lg border border-slate-300 text-sm hover:bg-slate-50 disabled:opacity-50"
            >
              Refresh history
            </button>
          </div>
        </div>

        {historyRows.length === 0 ? (
          <div className="text-sm text-slate-500">{historyLoading ? "Đang tải lịch sử round..." : "Chưa có round trong lịch sử."}</div>
        ) : (
          <div className="overflow-auto border border-slate-200 rounded-lg">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-50 text-slate-600">
                <tr>
                  <th className="text-left px-3 py-2">Round</th>
                  <th className="text-left px-3 py-2">Status</th>
                  <th className="text-left px-3 py-2">Created</th>
                  <th className="text-left px-3 py-2">Deadline</th>
                  <th className="text-right px-3 py-2">Updates</th>
                  <th className="text-right px-3 py-2">Agg Version</th>
                </tr>
              </thead>
              <tbody>
                {historyRows.map((r) => {
                  const tone = r.status === "AGGREGATED" ? "green" : r.status === "FAILED" ? "red" : "blue";
                  const updates = Array.isArray(r.updatedDeviceIds) ? r.updatedDeviceIds.length : 0;
                  return (
                    <tr key={`h-${r.roundId}`} className="border-t border-slate-100">
                      <td className="px-3 py-2 font-medium">#{r.roundId}</td>
                      <td className="px-3 py-2"><Badge text={r.status || "—"} tone={tone} /></td>
                      <td className="px-3 py-2">{r.createdAt || "—"}</td>
                      <td className="px-3 py-2">{r.deadlineAt || "—"}</td>
                      <td className="px-3 py-2 text-right">{updates}</td>
                      <td className="px-3 py-2 text-right">{r.aggregatedVersion ?? "—"}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        <div className="flex items-center justify-between text-xs text-slate-600">
          <div>Total: {historyTotalItems} rounds</div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => loadRoundHistory(Math.max(0, historyPage - 1))}
              disabled={historyLoading || historyPage <= 0}
              className="px-2.5 py-1.5 rounded border border-slate-300 disabled:opacity-50"
            >
              Prev
            </button>
            <span>
              Page {historyTotalPages === 0 ? 0 : historyPage + 1}/{historyTotalPages}
            </span>
            <button
              type="button"
              onClick={() => loadRoundHistory(historyPage + 1)}
              disabled={historyLoading || historyTotalPages === 0 || historyPage >= historyTotalPages - 1}
              className="px-2.5 py-1.5 rounded border border-slate-300 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      </Section>

      {error && (
        <div className="rounded-lg border border-rose-200 bg-rose-50 text-rose-700 text-sm p-3">
          <div className="font-semibold mb-1">Lỗi hệ thống:</div>
          <div>{error}</div>
        </div>
      )}

      {result && result.label === "Aggregate round" && Boolean(result.data.success) === true && (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 text-emerald-900 text-sm p-3">
          <div className="font-semibold mb-1">Aggregate thành công!</div>
          <div className="text-xs">Model version {result.data?.version || "—"} đã được tạo và gửi xuống thiết bị.</div>
        </div>
      )}
    </div>
  );
}
