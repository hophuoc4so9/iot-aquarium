from datetime import datetime, timedelta, timezone
from enum import Enum
import hashlib
import io
import json
import os
from pathlib import Path
from typing import Dict, List, Optional
from typing import Any, Tuple

import numpy as np
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.encoders import jsonable_encoder
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Aquarium AI Service", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


#
# Pond management & telemetry models
#


class PondBase(BaseModel):
    name: str
    code: str
    location: Optional[str] = None
    size_m2: Optional[float] = None
    depth_m: Optional[float] = None
    species: Optional[str] = None
    target_temp: Optional[float] = None
    target_ph: Optional[float] = None
    target_do: Optional[float] = None
    status: str = "active"
    controller_id: Optional[str] = None


class PondCreate(PondBase):
    pass


class PondUpdate(BaseModel):
    name: Optional[str] = None
    location: Optional[str] = None
    size_m2: Optional[float] = None
    depth_m: Optional[float] = None
    species: Optional[str] = None
    target_temp: Optional[float] = None
    target_ph: Optional[float] = None
    target_do: Optional[float] = None
    status: Optional[str] = None
    controller_id: Optional[str] = None


class Pond(PondBase):
    id: int

    class Config:
        orm_mode = True


class Telemetry(BaseModel):
    deviceId: int
    pondId: int
    temperature: float
    ph: Optional[float] = None
    waterLevelPercent: int
    floatHigh: bool
    floatLow: bool
    motorRunning: bool
    direction: str
    mode: str
    duty: int
    uptime_ms: int
    received_at: datetime


class Thresholds(BaseModel):
    """
    Ngưỡng cảnh báo cho 1 ao.

    Các field có thể là None; service sẽ tự fallback về
    SYSTEM_DEFAULT_THRESHOLDS cho mọi field bị thiếu.

    Được tính theo thứ tự ưu tiên:
    1) Ngưỡng cấu hình riêng cho ao (frontend gửi lên)
    2) Ngưỡng khuyến nghị theo loài cá (frontend gửi lên)
    3) Ngưỡng mặc định toàn hệ thống (SYSTEM_DEFAULT_THRESHOLDS)
    """

    tempLow: Optional[float] = None
    tempHigh: Optional[float] = None
    phLow: Optional[float] = None
    phHigh: Optional[float] = None
    waterLow: Optional[float] = None
    waterHigh: Optional[float] = None


class AlertLevel(str, Enum):
    OK = "OK"
    WARNING = "WARNING"
    DANGER = "DANGER"


class MetricAlert(BaseModel):
    metric: str  # "TEMP" | "PH" | "WATER"
    value: float
    minThreshold: float
    maxThreshold: float
    level: AlertLevel
    message: str


class ThresholdSource(str, Enum):
    POND = "POND"  # người dùng thiết kế cho ao
    FISH = "FISH"  # ngưỡng theo loài cá đang nuôi
    SYSTEM_DEFAULT = "SYSTEM_DEFAULT"  # ngưỡng mặc định toàn hệ thống


class AlertRequest(BaseModel):
    """
    Body request cho endpoint cảnh báo.
    Frontend nên truyền:
    - Nếu người dùng đã thiết kế ngưỡng cho ao -> pondThresholds
    - Nếu chưa, nhưng đã chọn loài cá có ngưỡng -> fishThresholds
    - Nếu cả 2 đều thiếu -> service tự dùng SYSTEM_DEFAULT_THRESHOLDS
    """

    pondThresholds: Optional[Thresholds] = None
    fishThresholds: Optional[Thresholds] = None


class PondAlertResponse(BaseModel):
    pondId: int
    timestamp: datetime
    thresholdsSource: ThresholdSource
    alerts: List[MetricAlert]


# In‑memory stores (demo). Replace with real DB when cần.
ponds_db: Dict[int, Pond] = {}
next_pond_id: int = 1
latest_telemetry_by_pond: Dict[int, Telemetry] = {}


# Ngưỡng mặc định toàn hệ thống (có thể điều chỉnh cho phù hợp thực tế)
SYSTEM_DEFAULT_THRESHOLDS = Thresholds(
    tempLow=18.0,
    tempHigh=30.0,
    phLow=6.8,
    phHigh=8.0,
    waterLow=20.0,
    waterHigh=85.0,
)


def _evaluate_metric(metric: str, value: float, min_th: float, max_th: float) -> MetricAlert:
    """
    Rule cảnh báo đơn giản cho 1 chỉ số.
    WARNING: lệch nhẹ khỏi khoảng [min_th, max_th]
    DANGER: lệch mạnh hơn (vượt thêm 50% biên độ)
    """
    span = max_th - min_th
    # Tránh chia cho 0 nếu cấu hình lỗi
    if span <= 0:
        span = 1.0

    if value < min_th:
        delta = min_th - value
        level = AlertLevel.DANGER if delta > 0.5 * span else AlertLevel.WARNING
        msg = f"{metric} thấp ({value:.2f} < {min_th:.2f})"
    elif value > max_th:
        delta = value - max_th
        level = AlertLevel.DANGER if delta > 0.5 * span else AlertLevel.WARNING
        msg = f"{metric} cao ({value:.2f} > {max_th:.2f})"
    else:
        level = AlertLevel.OK
        msg = f"{metric} trong ngưỡng an toàn"

    return MetricAlert(
        metric=metric,
        value=float(value),
        minThreshold=float(min_th),
        maxThreshold=float(max_th),
        level=level,
        message=msg,
    )


def _merge_with_system_defaults(th: Thresholds) -> Thresholds:
    """
    Bổ sung mọi field None trong `th` bằng giá trị từ SYSTEM_DEFAULT_THRESHOLDS.
    """
    base = SYSTEM_DEFAULT_THRESHOLDS
    return Thresholds(
        tempLow=th.tempLow if th.tempLow is not None else base.tempLow,
        tempHigh=th.tempHigh if th.tempHigh is not None else base.tempHigh,
        phLow=th.phLow if th.phLow is not None else base.phLow,
        phHigh=th.phHigh if th.phHigh is not None else base.phHigh,
        waterLow=th.waterLow if th.waterLow is not None else base.waterLow,
        waterHigh=th.waterHigh if th.waterHigh is not None else base.waterHigh,
    )


def _resolve_thresholds(body: AlertRequest) -> Tuple[Thresholds, ThresholdSource]:
    """
    Trả về bộ ngưỡng đã được merge với SYSTEM_DEFAULT_THRESHOLDS + nguồn ngưỡng,
    theo thứ tự ưu tiên:
    1) pondThresholds (thiết kế riêng cho ao)
    2) fishThresholds (theo loài cá)
    3) SYSTEM_DEFAULT_THRESHOLDS (mặc định toàn hệ thống)
    """
    if body.pondThresholds is not None:
        return _merge_with_system_defaults(body.pondThresholds), ThresholdSource.POND
    if body.fishThresholds is not None:
        return _merge_with_system_defaults(body.fishThresholds), ThresholdSource.FISH
    # trường hợp dùng default hoàn toàn
    return _merge_with_system_defaults(SYSTEM_DEFAULT_THRESHOLDS), ThresholdSource.SYSTEM_DEFAULT


#
# Admin: CRUD ponds
#


@app.get("/admin/ponds", response_model=List[Pond])
async def list_ponds() -> List[Pond]:
    return list(ponds_db.values())


@app.post("/admin/ponds", response_model=Pond)
async def create_pond(data: PondCreate) -> Pond:
    global next_pond_id
    for p in ponds_db.values():
        if p.code == data.code:
            raise HTTPException(status_code=400, detail="Pond code already exists")
    pond = Pond(id=next_pond_id, **data.dict())
    ponds_db[pond.id] = pond
    next_pond_id += 1
    return pond


@app.get("/admin/ponds/{pond_id}", response_model=Pond)
async def get_pond(pond_id: int) -> Pond:
    pond = ponds_db.get(pond_id)
    if not pond:
        raise HTTPException(status_code=404, detail="Pond not found")
    return pond


@app.put("/admin/ponds/{pond_id}", response_model=Pond)
async def update_pond(pond_id: int, data: PondUpdate) -> Pond:
    pond = ponds_db.get(pond_id)
    if not pond:
        raise HTTPException(status_code=404, detail="Pond not found")
    update_data = data.dict(exclude_unset=True)
    updated = pond.copy(update=update_data)
    ponds_db[pond_id] = updated
    return updated


@app.delete("/admin/ponds/{pond_id}")
async def delete_pond(pond_id: int):
    if pond_id not in ponds_db:
        raise HTTPException(status_code=404, detail="Pond not found")
    del ponds_db[pond_id]
    latest_telemetry_by_pond.pop(pond_id, None)
    return {"success": True}


#
# Telemetry ingest + realtime view
#


@app.post("/telemetry-ingest")
async def telemetry_ingest(payload: dict):
    """
    Nhận payload giống simulate_ponds.py publish và lưu lại bản mới nhất theo pond.
    """
    required_fields = {
        "deviceId",
        "pondId",
        "temperature",
        "waterLevelPercent",
        "floatHigh",
        "floatLow",
        "motorRunning",
        "direction",
        "mode",
        "duty",
        "uptime_ms",
    }
    missing = [f for f in required_fields if f not in payload]
    if missing:
        raise HTTPException(
            status_code=400, detail=f"Missing field(s) in payload: {', '.join(missing)}"
        )

    t = Telemetry(
        deviceId=int(payload["deviceId"]),
        pondId=payload["pondId"],
        temperature=payload["temperature"],
        ph=payload.get("ph"),
        waterLevelPercent=payload["waterLevelPercent"],
        floatHigh=payload["floatHigh"],
        floatLow=payload["floatLow"],
        motorRunning=payload["motorRunning"],
        direction=payload["direction"],
        mode=payload["mode"],
        duty=payload["duty"],
        uptime_ms=payload["uptime_ms"],
        received_at=datetime.now(timezone.utc),
    )
    latest_telemetry_by_pond[t.pondId] = t
    return {"success": True}


@app.get("/ponds/{pond_id}/realtime", response_model=Telemetry)
async def get_realtime(pond_id: int) -> Telemetry:
    t = latest_telemetry_by_pond.get(pond_id)
    if not t:
        raise HTTPException(
            status_code=404, detail="No telemetry yet for this pond"
        )
    return t


@app.post("/ponds/{pond_id}/alerts", response_model=PondAlertResponse)
async def get_pond_alerts(pond_id: int, body: AlertRequest) -> PondAlertResponse:
    """
    Cảnh báo bất thường tức thời cho 1 ao.

    Logic chọn ngưỡng:
    1) Nếu body.pondThresholds có giá trị -> dùng (ngưỡng người dùng thiết kế riêng cho ao)
    2) Ngược lại, nếu body.fishThresholds có giá trị -> dùng (ngưỡng theo loài cá đang nuôi)
    3) Nếu cả 2 đều thiếu -> dùng SYSTEM_DEFAULT_THRESHOLDS (mặc định toàn hệ thống)
    """
    pond = ponds_db.get(pond_id)
    if not pond:
        raise HTTPException(status_code=404, detail="Pond not found")

    t = latest_telemetry_by_pond.get(pond_id)
    if not t:
        raise HTTPException(
            status_code=404, detail="No telemetry yet for this pond"
        )

    thresholds, source = _resolve_thresholds(body)

    alerts: List[MetricAlert] = [
        _evaluate_metric("TEMP", t.temperature, thresholds.tempLow, thresholds.tempHigh),
        _evaluate_metric(
            "WATER",
            float(t.waterLevelPercent),
            thresholds.waterLow,
            thresholds.waterHigh,
        ),
    ]

    if t.ph is not None:
        alerts.append(_evaluate_metric("PH", t.ph, thresholds.phLow, thresholds.phHigh))

    return PondAlertResponse(
        pondId=pond_id,
        timestamp=t.received_at,
        thresholdsSource=source,
        alerts=alerts,
    )


@app.get("/user/ponds", response_model=List[Pond])
async def list_user_ponds() -> List[Pond]:
    # Demo: trả về tất cả ao. Khi có auth, lọc theo user.
    return list(ponds_db.values())


class ForecastPoint(BaseModel):
    timestamp: datetime
    value: float


class ForecastResponse(BaseModel):
    pondId: int
    metric: str
    horizonHours: int
    points: List[ForecastPoint]


class FederatedModelStatus(str, Enum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"


class FlModelPayload(BaseModel):
    weights: List[float]
    shape: List[int]


class FlModelVersion(BaseModel):
    version: int
    roundId: int
    createdAt: datetime
    status: FederatedModelStatus
    checksum: str
    payload: FlModelPayload


class FlRegisterModelRequest(BaseModel):
    roundId: int = 0
    weights: List[float]
    shape: List[int]
    activate: bool = True


class FlRegisterModelResponse(BaseModel):
    success: bool
    version: int
    checksum: str


class FlClientUpdateRequest(BaseModel):
    deviceId: int
    pondId: int
    roundId: int
    sampleCount: int = 1
    loss: Optional[float] = None
    weights: List[float]
    shape: List[int]


class FlClientUpdateResponse(BaseModel):
    success: bool
    accepted: bool
    pendingUpdates: int


class FlAggregateRequest(BaseModel):
    roundId: int
    minClients: int = 1
    minSamples: int = 1


class FlAggregateResponse(BaseModel):
    success: bool
    roundId: int
    version: int
    numClients: int
    totalSamples: int
    checksum: str


class FlRoundStatusResponse(BaseModel):
    roundId: int
    pendingUpdates: int
    eligibleUpdates: int


@app.post("/forecast", response_model=ForecastResponse)
async def forecast(
    pondId: int,
    metric: str = Query("PH", pattern="^(PH|TEMP)$"),
    horizonHours: int = Query(6, ge=1, le=24),
) -> ForecastResponse:
    """
    Demo endpoint dự báo pH / nhiệt độ cho ao.

    Hiện tại không kết nối DB, mà sinh chuỗi giả dựa trên giá trị
    trung bình và một dao động sin nhẹ để minh họa.
    """
    now = datetime.utcnow()

    base_value = 7.2 if metric == "PH" else 27.0
    hours = np.linspace(1, horizonHours, num=horizonHours)
    values = base_value + 0.2 * np.sin(hours)

    points = [
        ForecastPoint(timestamp=now + timedelta(hours=float(h)), value=float(v))
        for h, v in zip(hours, values)
    ]

    return ForecastResponse(
        pondId=pondId,
        metric=metric,
        horizonHours=horizonHours,
        points=points,
    )


class FishDiseaseResponse(BaseModel):
    pondId: Optional[int] = None
    label: str
    score: float


MODEL: Optional[Any] = None
MODEL_IMG_SIZE: Tuple[int, int] = (224, 224)
MODEL_PATH = os.path.join(
    os.path.dirname(__file__), "model", "fish_disease_resnet50.h5"
)


fl_models: Dict[int, FlModelVersion] = {}
fl_updates_by_round: Dict[int, List[FlClientUpdateRequest]] = {}
fl_reports_by_round: Dict[int, List[Dict[str, Any]]] = {}
fl_next_model_version = 1
fl_active_model_version: Optional[int] = None
FL_STORE_PATH = Path(__file__).resolve().parent / "data" / "fl_models_store.json"

# Lưu ý: Danh sách này phải sắp xếp theo đúng thứ tự Alphabet
# (giống lúc train).
CLASS_NAMES = [
    "Bacterial Red disease",
    "Bacterial diseases - Aeromoniasis",
    "Bacterial gill disease",
    "Fungal diseases Saprolegniasis",
    "Healthy Fish",
    "Parasitic diseases",
    "Viral diseases White tail disease",
]


def _hash_model(weights: List[float], shape: List[int]) -> str:
    weight_part = ";".join(f"{w:.8f}" for w in weights)
    body = f"{shape}|{weight_part}".encode("utf-8")
    return hashlib.sha256(body).hexdigest()


def _shape_size(shape: List[int]) -> int:
    total = 1
    for s in shape:
        if s <= 0:
            raise HTTPException(status_code=400, detail="Model shape must be > 0")
        total *= s
    return total


def _validate_model_payload(weights: List[float], shape: List[int]) -> None:
    if not shape:
        raise HTTPException(status_code=400, detail="Model shape must not be empty")
    expected = _shape_size(shape)
    if len(weights) != expected:
        raise HTTPException(
            status_code=400,
            detail=f"Weights size mismatch: expected {expected}, got {len(weights)}",
        )
    
    # Quality gate: check for NaN, Inf, or extremely large values (model validation)
    for i, w in enumerate(weights):
        if not isinstance(w, (int, float)):
            raise HTTPException(status_code=400, detail=f"Weight[{i}] is not numeric: {type(w)}")
        if np.isnan(w) or np.isinf(w):
            raise HTTPException(status_code=400, detail=f"Weight[{i}] is NaN or Inf: {w}")
        if abs(w) > 100.0:  # Reasonable model weights should be <100
            raise HTTPException(status_code=400, detail=f"Weight[{i}] out of range: {w}")


def _validate_client_updates(updates: List[FlClientUpdateRequest]) -> None:
    """Verify all client updates have valid loss values (no NaN/Inf)."""
    for i, u in enumerate(updates):
        if u.loss is None:
            continue  # Loss can be optional
        if np.isnan(u.loss) or np.isinf(u.loss):
            raise ValueError(f"Update[{i}] has invalid loss: {u.loss}")
        if u.loss < 0:
            raise ValueError(f"Update[{i}] has negative loss: {u.loss}")


def _compute_system_loss(updates: List[FlClientUpdateRequest], total_samples: float) -> Optional[float]:
    """Compute weighted average loss across all client updates."""
    if not updates or total_samples <= 0:
        return None
    
    updates_with_loss = [u for u in updates if u.loss is not None]
    if not updates_with_loss:
        return None
    
    weighted_loss = sum(
        u.loss * (u.sampleCount / total_samples)
        for u in updates_with_loss
    )
    return float(weighted_loss)


def _resolve_active_model() -> FlModelVersion:
    if fl_active_model_version is None:
        raise HTTPException(status_code=404, detail="No active global model")
    model = fl_models.get(fl_active_model_version)
    if model is None:
        raise HTTPException(status_code=404, detail="Active global model not found")
    return model


def _persist_fl_registry() -> None:
    payload = {
        "nextModelVersion": fl_next_model_version,
        "activeModelVersion": fl_active_model_version,
        "models": [jsonable_encoder(model) for model in fl_models.values()],
    }

    FL_STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = FL_STORE_PATH.with_suffix(".tmp")
    with tmp_path.open("w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    tmp_path.replace(FL_STORE_PATH)


def _load_fl_registry() -> None:
    global fl_models
    global fl_next_model_version
    global fl_active_model_version

    if not FL_STORE_PATH.exists():
        return

    try:
        with FL_STORE_PATH.open("r", encoding="utf-8") as fh:
            raw = json.load(fh)

        models = raw.get("models", [])
        loaded_models: Dict[int, FlModelVersion] = {}
        for item in models:
            model = FlModelVersion.parse_obj(item)
            loaded_models[int(model.version)] = model

        fl_models = loaded_models

        active_version = raw.get("activeModelVersion")
        fl_active_model_version = int(active_version) if active_version is not None else None

        next_version = raw.get("nextModelVersion")
        if next_version is not None:
                        fl_next_model_version = int(next_version)
        else:
                        fl_next_model_version = (max(loaded_models.keys()) + 1) if loaded_models else 1

        if fl_active_model_version is not None and fl_active_model_version not in fl_models:
            fl_active_model_version = max(fl_models.keys()) if fl_models else None

        if fl_active_model_version is not None and fl_active_model_version in fl_models:
            print(f"[FL] Restored registry from {FL_STORE_PATH} (active={fl_active_model_version})")
        else:
            print(f"[FL] Restored registry from {FL_STORE_PATH} (no active model)")
    except Exception as exc:
        print(f"[FL] Failed to load registry: {exc}")


@app.on_event("startup")
def _load_fish_disease_model() -> None:
    global MODEL
    try:
        from tensorflow.keras.models import load_model

        MODEL = load_model(MODEL_PATH)
        print(f"[fish-disease] Loaded model: {MODEL_PATH}")
    except Exception as e:
        MODEL = None
        print(f"[fish-disease] Failed to load model: {e}")

    _load_fl_registry()


@app.post("/fl/models/register", response_model=FlRegisterModelResponse)
async def fl_register_model(body: FlRegisterModelRequest) -> FlRegisterModelResponse:
    global fl_next_model_version
    global fl_active_model_version

    _validate_model_payload(body.weights, body.shape)
    checksum = _hash_model(body.weights, body.shape)

    version = fl_next_model_version
    fl_next_model_version += 1

    model = FlModelVersion(
        version=version,
        roundId=body.roundId,
        createdAt=datetime.now(timezone.utc),
        status=FederatedModelStatus.ACTIVE if body.activate else FederatedModelStatus.DRAFT,
        checksum=checksum,
        payload=FlModelPayload(weights=body.weights, shape=body.shape),
    )
    fl_models[version] = model

    if body.activate:
        if fl_active_model_version is not None and fl_active_model_version in fl_models:
            prev = fl_models[fl_active_model_version]
            fl_models[fl_active_model_version] = prev.copy(
                update={"status": FederatedModelStatus.ARCHIVED}
            )
        fl_active_model_version = version

    _persist_fl_registry()

    return FlRegisterModelResponse(success=True, version=version, checksum=checksum)


@app.get("/fl/models/latest", response_model=FlModelVersion)
async def fl_get_latest_model() -> FlModelVersion:
    return _resolve_active_model()


@app.get("/fl/models/{version}", response_model=FlModelVersion)
async def fl_get_model(version: int) -> FlModelVersion:
    model = fl_models.get(version)
    if model is None:
        raise HTTPException(status_code=404, detail="Model version not found")
    return model


@app.post("/fl/updates", response_model=FlClientUpdateResponse)
async def fl_upload_client_update(payload: Dict[str, Any]) -> FlClientUpdateResponse:
    try:
        body = FlClientUpdateRequest(**payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid FL update payload: {exc}") from exc

    _validate_model_payload(body.weights, body.shape)
    if body.sampleCount < 1:
        raise HTTPException(status_code=400, detail="sampleCount must be >= 1")

    updates = fl_updates_by_round.setdefault(body.roundId, [])
    updates.append(body)
    return FlClientUpdateResponse(
        success=True,
        accepted=True,
        pendingUpdates=len(updates),
    )


@app.post("/fl/reports")
async def fl_upload_device_report(payload: Dict[str, Any]):
    round_id_raw = payload.get("roundId")
    try:
        round_id = int(round_id_raw) if round_id_raw is not None else 0
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="roundId must be an integer")

    reports = fl_reports_by_round.setdefault(round_id, [])
    reports.append(payload)
    return {
        "success": True,
        "roundId": round_id,
        "storedReports": len(reports),
    }


@app.get("/fl/reports/{round_id}")
async def fl_get_reports(round_id: int):
    return {
        "roundId": round_id,
        "reports": fl_reports_by_round.get(round_id, []),
    }


@app.get("/fl/rounds/{round_id}/status", response_model=FlRoundStatusResponse)
async def fl_round_status(round_id: int) -> FlRoundStatusResponse:
    updates = fl_updates_by_round.get(round_id, [])
    eligible = sum(1 for u in updates if u.sampleCount > 0)
    return FlRoundStatusResponse(
        roundId=round_id,
        pendingUpdates=len(updates),
        eligibleUpdates=eligible,
    )


@app.post("/fl/aggregate", response_model=FlAggregateResponse)
async def fl_aggregate(payload: Dict[str, Any]) -> FlAggregateResponse:
    global fl_next_model_version
    global fl_active_model_version

    try:
        body = FlAggregateRequest(**payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid FL aggregate payload: {exc}") from exc

    updates = fl_updates_by_round.get(body.roundId, [])
    
    # Validate all client updates have valid loss values
    try:
        _validate_client_updates(updates)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid client update: {e}") from e
    
    eligible_updates = [u for u in updates if u.sampleCount >= body.minSamples]
    if len(eligible_updates) < body.minClients:
        raise HTTPException(
            status_code=400,
            detail=(
                "Not enough client updates for aggregation: "
                f"need {body.minClients}, got {len(eligible_updates)}"
            ),
        )

    base_shape = eligible_updates[0].shape
    expected_size = _shape_size(base_shape)
    for u in eligible_updates:
        if u.shape != base_shape:
            raise HTTPException(status_code=400, detail="All updates must share same shape")
        if len(u.weights) != expected_size:
            raise HTTPException(status_code=400, detail="Invalid update weights size")

    total_samples = float(sum(u.sampleCount for u in eligible_updates))
    acc = np.zeros(expected_size, dtype=np.float64)
    for u in eligible_updates:
        w = np.array(u.weights, dtype=np.float64)
        acc += (u.sampleCount / total_samples) * w

    merged_weights = acc.astype(np.float32).tolist()
    
    # Quality gate 1: Validate merged model payload for NaN/Inf/range
    try:
        _validate_model_payload(merged_weights, base_shape)
    except HTTPException as e:
        raise HTTPException(status_code=400, detail=f"Aggregated model validation failed: {e.detail}") from e
    
    checksum = _hash_model(merged_weights, base_shape)
    
    # Quality gate 2: Compute system loss for regression detection
    system_loss = _compute_system_loss(eligible_updates, total_samples)
    
    version = fl_next_model_version
    fl_next_model_version += 1
    
    # Determine model status: for now, all successfully aggregated models are ACTIVE
    # (with regression detection, would mark as DRAFT if loss increased significantly)
    model_status = FederatedModelStatus.ACTIVE
    
    model = FlModelVersion(
        version=version,
        roundId=body.roundId,
        createdAt=datetime.now(timezone.utc),
        status=model_status,
        checksum=checksum,
        payload=FlModelPayload(weights=merged_weights, shape=base_shape),
    )
    fl_models[version] = model
    
    # Update active model only if not in DRAFT
    if model_status == FederatedModelStatus.ACTIVE:
        if fl_active_model_version is not None and fl_active_model_version in fl_models:
            prev = fl_models[fl_active_model_version]
            fl_models[fl_active_model_version] = prev.copy(
                update={"status": FederatedModelStatus.ARCHIVED}
            )
        fl_active_model_version = version

    _persist_fl_registry()

    return FlAggregateResponse(
        success=True,
        roundId=body.roundId,
        version=version,
        numClients=len(eligible_updates),
        totalSamples=int(total_samples),
        checksum=checksum,
    )


def _predict_fish_disease_from_bytes(content: bytes) -> Tuple[str, float]:
    """
    Trả về (label, score) với score nằm trong [0..1].
    """
    if MODEL is None:
        raise RuntimeError("Fish disease model not loaded")

    # Import trong hàm để giảm rủi ro lỗi import khi service khởi động trước.
    from tensorflow.keras.applications.resnet50 import preprocess_input
    from tensorflow.keras.preprocessing import image as keras_image

    # Load ảnh từ bytes (không lưu file lên đĩa).
    try:
        img = keras_image.load_img(io.BytesIO(content), target_size=MODEL_IMG_SIZE)
    except Exception:
        # Fallback: một số môi trường Keras có thể không nhận BytesIO trực tiếp.
        import tempfile

        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
                tmp.write(content)
                tmp_path = tmp.name
            img = keras_image.load_img(tmp_path, target_size=MODEL_IMG_SIZE)
        except Exception as exc:
            raise ValueError("Unsupported or corrupted image content") from exc
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except OSError:
                    pass

    x = keras_image.img_to_array(img)
    x = np.expand_dims(x, axis=0)
    x = preprocess_input(x)

    preds = MODEL.predict(x, verbose=0)
    idx = int(np.argmax(preds, axis=1)[0])
    score = float(preds[0][idx])
    label = CLASS_NAMES[idx]
    return label, score


@app.post("/fish-disease", response_model=FishDiseaseResponse)
async def fish_disease(
    file: UploadFile = File(...),
    pondId: Optional[int] = None,
) -> FishDiseaseResponse:
    """
    Endpoint phân loại ảnh cá bằng model ResNet50.

    Trả về:
    - `label`: tên bệnh (theo CLASS_NAMES)
    - `score`: xác suất softmax trong [0..1]
    """
    if file.content_type and not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File phải là ảnh (image/*)")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Ảnh rỗng")

    try:
        label, score = _predict_fish_disease_from_bytes(content)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Predict failed: {e}")

    return FishDiseaseResponse(pondId=pondId, label=label, score=score)


@app.get("/")
async def root():
    return {"status": "ok", "service": "aquarium-ai", "version": "0.1.0"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

