from datetime import datetime, timedelta, timezone
from enum import Enum
import io
import os
from typing import Dict, List, Optional
from typing import Any, Tuple

import numpy as np
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
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
    deviceId: str
    pondId: int
    temperature: float
    ph: float
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


def _resolve_thresholds(body: AlertRequest) -> (Thresholds, ThresholdSource):
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
        "ph",
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
        deviceId=payload["deviceId"],
        pondId=payload["pondId"],
        temperature=payload["temperature"],
        ph=payload["ph"],
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
        _evaluate_metric("PH", t.ph, thresholds.phLow, thresholds.phHigh),
        _evaluate_metric(
            "WATER",
            float(t.waterLevelPercent),
            thresholds.waterLow,
            thresholds.waterHigh,
        ),
    ]

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

        with tempfile.NamedTemporaryFile(suffix=".jpg") as tmp:
            tmp.write(content)
            tmp.flush()
            img = keras_image.load_img(tmp.name, target_size=MODEL_IMG_SIZE)

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
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File phải là ảnh (image/*)")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Ảnh rỗng")

    try:
        label, score = _predict_fish_disease_from_bytes(content)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Predict failed: {e}")

    return FishDiseaseResponse(pondId=pondId, label=label, score=score)


@app.get("/")
async def root():
    return {"status": "ok", "service": "aquarium-ai", "version": "0.1.0"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

