#!/usr/bin/env python3
"""MQTT smoke test for ESP32 aquarium firmware.

Requires a running device connected to the same broker and using matching
DEVICE_ID/POND_ID topic naming from firmware.
"""

from __future__ import annotations

import argparse
import json
import threading
import time
import zlib
from typing import Any, Dict, List, Optional

import paho.mqtt.client as mqtt


class SmokeState:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.status_payloads: List[Dict[str, Any]] = []
        self.telemetry_payloads: List[Dict[str, Any]] = []
        self.train_done_payloads: List[Dict[str, Any]] = []
        self.metrics_payloads: List[Dict[str, Any]] = []

    def add(self, bucket: str, payload: Dict[str, Any]) -> None:
        with self.lock:
            getattr(self, bucket).append(payload)

    def count(self, bucket: str) -> int:
        with self.lock:
            return len(getattr(self, bucket))


def parse_json(payload: bytes) -> Optional[Dict[str, Any]]:
    try:
        return json.loads(payload.decode("utf-8", errors="ignore"))
    except Exception:
        return None


def wait_for_count(state: SmokeState, bucket: str, target_count: int, timeout_s: float) -> bool:
    end = time.time() + timeout_s
    while time.time() < end:
        if state.count(bucket) >= target_count:
            return True
        time.sleep(0.1)
    return False


def require_fields(payload: Dict[str, Any], fields: List[str], name: str) -> Optional[str]:
    missing = [f for f in fields if f not in payload]
    if missing:
        return f"{name} missing fields: {', '.join(missing)}"
    return None


def to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return default


def main() -> int:
    parser = argparse.ArgumentParser(description="ESP32 FL MQTT smoke test")
    parser.add_argument("--broker", default="broker.emqx.io")
    parser.add_argument("--port", type=int, default=1883)
    parser.add_argument("--device-id", type=int, default=5)
    parser.add_argument("--pond-id", type=int, default=5)
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--model-version", type=int, default=999)
    parser.add_argument("--weights", default="0.03,0.08,0.03,0.02,0.78,0.02,0.02,0.02")
    parser.add_argument("--strict", action="store_true", help="Enable strict payload validation")
    args = parser.parse_args()

    state = SmokeState()
    connected = threading.Event()

    status_topic = f"esp32/pond/{args.pond_id}/status"
    telemetry_topic = f"esp32/pond/{args.pond_id}/telemetry"
    train_done_topic = f"fl/model/{args.device_id}/train/done"
    metrics_topic = f"fl/metrics/{args.device_id}/report"

    cmd_topic = f"aquarium/pond/{args.pond_id}/pump/cmd"
    mode_topic = f"aquarium/pond/{args.pond_id}/pump/mode"
    train_start_topic = f"fl/model/{args.device_id}/train/start"
    model_download_topic = f"fl/model/{args.device_id}/download"

    def on_connect(client: mqtt.Client, _userdata: Any, _flags: Dict[str, Any], rc: int) -> None:
        if rc == 0:
            client.subscribe(status_topic)
            client.subscribe(telemetry_topic)
            client.subscribe(train_done_topic)
            client.subscribe(metrics_topic)
            connected.set()

    def on_message(_client: mqtt.Client, _userdata: Any, msg: mqtt.MQTTMessage) -> None:
        data = parse_json(msg.payload)
        if data is None:
            return
        if msg.topic == status_topic:
            state.add("status_payloads", data)
        elif msg.topic == telemetry_topic:
            state.add("telemetry_payloads", data)
        elif msg.topic == train_done_topic:
            state.add("train_done_payloads", data)
        elif msg.topic == metrics_topic:
            state.add("metrics_payloads", data)

    client = mqtt.Client(client_id=f"fl-smoke-{int(time.time())}", clean_session=True)
    client.on_connect = on_connect
    client.on_message = on_message

    print(f"[INFO] Connecting MQTT {args.broker}:{args.port} ...")
    client.connect(args.broker, args.port, keepalive=30)
    client.loop_start()

    if not connected.wait(timeout=args.timeout):
        print("[FAIL] MQTT connect/subscribe timeout")
        client.loop_stop()
        client.disconnect()
        return 1

    print("[STEP] Request MANUAL mode + FORWARD + STOP")
    base_status_count = state.count("status_payloads")
    client.publish(mode_topic, "MANUAL")
    client.publish(cmd_topic, "DUTY:512")
    client.publish(cmd_topic, "FORWARD")
    time.sleep(1.2)
    client.publish(cmd_topic, "STOP")

    if not wait_for_count(state, "status_payloads", base_status_count + 1, args.timeout):
        print("[FAIL] No status payload received after motor commands")
        client.loop_stop()
        client.disconnect()
        return 2

    print("[STEP] Trigger FL local train")
    base_done_count = state.count("train_done_payloads")
    base_metrics_count = state.count("metrics_payloads")
    client.publish(train_start_topic, "ROUND:101|SAMPLES:24|EPOCHS:2")

    done_ok = wait_for_count(state, "train_done_payloads", base_done_count + 1, args.timeout)
    metrics_ok = wait_for_count(state, "metrics_payloads", base_metrics_count + 1, args.timeout)
    if not (done_ok and metrics_ok):
        print("[FAIL] FL training response timeout (train_done or metrics missing)")
        client.loop_stop()
        client.disconnect()
        return 3

    print("[STEP] Trigger global model download")
    crc = zlib.crc32(args.weights.encode("utf-8")) & 0xFFFFFFFF
    payload = f"VERSION:{args.model_version}|WEIGHTS:{args.weights}|WCRC:{crc:08x}"
    client.publish(model_download_topic, payload)

    # Give device a brief moment to apply and continue telemetry.
    time.sleep(1.0)

    status_count = state.count("status_payloads")
    telemetry_count = state.count("telemetry_payloads")
    done_count = state.count("train_done_payloads")
    metrics_count = state.count("metrics_payloads")

    if args.strict:
        errors: List[str] = []
        expected_dim = len([x for x in args.weights.split(",") if x.strip()])

        if telemetry_count < 1:
            errors.append("telemetry payload not received")
        else:
            t = state.telemetry_payloads[-1]
            msg = require_fields(
                t,
                [
                    "deviceId",
                    "pondId",
                    "temperature",
                    "waterLevelPercent",
                    "motorRunning",
                    "direction",
                    "anomalyScore",
                    "anomalyFlag",
                    "duty",
                    "mode",
                    "uptime_ms",
                ],
                "telemetry",
            )
            if msg:
                errors.append(msg)

        if done_count < 1:
            errors.append("train_done payload not received")
        else:
            d = state.train_done_payloads[-1]
            msg = require_fields(
                d,
                [
                    "roundId",
                    "modelVersion",
                    "success",
                    "loss",
                    "sampleCount",
                    "shape",
                    "weights",
                    "reason",
                ],
                "train_done",
            )
            if msg:
                errors.append(msg)
            else:
                shape = d.get("shape")
                weights = d.get("weights")
                if not isinstance(shape, list) or len(shape) != 1:
                    errors.append("train_done.shape must be [dim]")
                else:
                    if to_int(shape[0], -1) != expected_dim:
                        errors.append(
                            f"train_done.shape dim mismatch: expected {expected_dim}, got {shape[0]}"
                        )
                if not isinstance(weights, list) or len(weights) != expected_dim:
                    errors.append(
                        f"train_done.weights length mismatch: expected {expected_dim}, got {len(weights) if isinstance(weights, list) else 'non-list'}"
                    )

        if metrics_count < 1:
            errors.append("metrics payload not received")
        else:
            m = state.metrics_payloads[-1]
            msg = require_fields(m, ["roundId", "loss", "sampleCount", "weights"], "metrics")
            if msg:
                errors.append(msg)

        if errors:
            print("[FAIL] Strict validation failed")
            for e in errors:
                print(f"  - {e}")
            client.loop_stop()
            client.disconnect()
            return 4

    print("[PASS] Smoke test completed")
    print(f"  status messages:   {status_count}")
    print(f"  telemetry messages:{telemetry_count}")
    print(f"  train done:        {done_count}")
    print(f"  metrics:           {metrics_count}")

    client.loop_stop()
    client.disconnect()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
