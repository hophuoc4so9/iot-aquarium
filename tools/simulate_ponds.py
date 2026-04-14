import json
import os
import random
import time
from dataclasses import dataclass

import paho.mqtt.client as mqtt


BROKER_HOST = "broker.emqx.io"
BROKER_PORT = 1883
TOPIC = "nckh/iot-aquarium/esp32/telemetry"
POND_TOPIC_PREFIX = "nckh/iot-aquarium/esp32/pond"
# Default to mock devices for local testing.
# Real ESP32-S3 hardware can be reserved for deviceId=5.
DEFAULT_DEVICE_IDS = "1,2,3"


@dataclass
class DeviceState:
  pond_id: int
  model_version: int = 1


def build_states_from_env() -> dict[int, DeviceState]:
  raw = os.getenv("SIM_DEVICE_IDS", DEFAULT_DEVICE_IDS)
  states: dict[int, DeviceState] = {}

  for token in raw.split(","):
    token = token.strip()
    if not token:
      continue
    try:
      device_id = int(token)
    except ValueError:
      continue
    if device_id <= 0:
      continue
    # For simulator simplicity, use pondId = deviceId.
    states[device_id] = DeviceState(pond_id=device_id)

  if states:
    return states

  # Safe fallback when env contains invalid values.
  return {
    1: DeviceState(pond_id=1),
    2: DeviceState(pond_id=2),
    3: DeviceState(pond_id=3),
  }


def make_sample(device_id: int, pond_id: int, t: int) -> dict:
  """Tạo 1 mẫu dữ liệu giả lập cho ao."""
  base_temp = 27.0 + random.uniform(-1.0, 1.0)
  base_ph = 7.2 + random.uniform(-0.3, 0.3)

  # Đơn giản: 2 ao an toàn, 1 ao hơi xấu để test cảnh báo
  if pond_id == 3 and t % 10 > 5:
    # Ao 3 thỉnh thoảng pH lệch
    base_ph += random.uniform(0.8, 1.3)

  # Mực nước: random trong khoảng 15–95
  water_percent = random.choice([15, 50, 95])
  float_high = water_percent >= 90
  float_low = water_percent >= 40

  motor_running = random.random() < 0.3
  direction = random.choice(["FORWARD", "BACKWARD", "STOPPED"])

  return {
    "deviceId": device_id,
    "pondId": pond_id,
    "pond_id": pond_id,
    "temperature": round(base_temp, 2),
    "ph": round(base_ph, 2),
    "waterLevel": water_percent,
    "waterLevelPercent": water_percent,
    "floatHigh": float_high,
    "floatLow": float_low,
    "motorRunning": motor_running,
    "direction": direction,
    "mode": "AUTO",
    "duty": 512,
    "uptime_ms": int(time.time() * 1000),
  }


def parse_train_start(payload: str) -> dict:
  """Parse payload dạng ROUND:3|EPOCHS:1|SAMPLES:16 từ backend."""
  values = {}
  for part in payload.split("|"):
    if ":" not in part:
      continue
    key, value = part.split(":", 1)
    values[key.strip().upper()] = value.strip()

  return {
    "roundId": int(values.get("ROUND", "0") or 0),
    "epochs": int(values.get("EPOCHS", "1") or 1),
    "samples": int(values.get("SAMPLES", "16") or 16),
  }


def fake_local_update(device_id: int, state: DeviceState, train_cfg: dict) -> dict:
  """Sinh local update giả lập theo round để backend/AI nhận được report hợp lệ."""
  rng = random.Random(device_id * 100000 + train_cfg["roundId"])
  weights = [round(rng.uniform(-1.2, 1.2), 6) for _ in range(8)]
  loss = round(max(0.01, rng.uniform(0.02, 0.45)), 6)

  return {
    "deviceId": device_id,
    "pondId": state.pond_id,
    "roundId": train_cfg["roundId"],
    "sampleCount": max(1, int(train_cfg["samples"])),
    "loss": loss,
    "shape": [8],
    "weights": weights,
    "modelVersion": state.model_version,
    "success": True,
    "source": "python-simulator",
    "timestamp": int(time.time() * 1000),
  }


def on_message(client: mqtt.Client, userdata: dict, message: mqtt.MQTTMessage):
  topic = message.topic
  payload = message.payload.decode("utf-8", errors="ignore")
  print(f"[MQTT] {topic} -> {payload}")

  parts = topic.split("/")
  if len(parts) < 5:
    return

  # Topic train command: fl/model/{deviceId}/train/start
  if not (parts[0] == "fl" and parts[1] == "model" and parts[3] == "train" and parts[4] == "start"):
    return

  try:
    device_id = int(parts[2])
  except ValueError:
    return

  states: dict[int, DeviceState] = userdata.get("states", {})
  state = states.get(device_id)
  if state is None:
    return

  train_cfg = parse_train_start(payload)
  if train_cfg["roundId"] <= 0:
    print(f"[SIM] Ignore invalid ROUND in payload: {payload}")
    return

  report = fake_local_update(device_id, state, train_cfg)
  done_topic = f"fl/model/{device_id}/train/done"
  report_topic = f"fl/metrics/{device_id}/report"
  report_body = json.dumps(report)

  client.publish(done_topic, report_body, qos=0, retain=False)
  client.publish(report_topic, report_body, qos=0, retain=False)
  print(f"[FL] {done_topic} <- {report_body}")
  print(f"[FL] {report_topic} <- {report_body}")


def main():
  client = mqtt.Client()
  print(f"Connecting to MQTT broker {BROKER_HOST}:{BROKER_PORT} ...")

  states = build_states_from_env()
  print(f"[SIM] Device IDs: {', '.join(str(x) for x in states.keys())}")

  client.user_data_set({"states": states})
  client.on_message = on_message
  client.connect(BROKER_HOST, BROKER_PORT, keepalive=60)

  for device_id in states:
    client.subscribe(f"fl/model/{device_id}/train/start")

  client.loop_start()

  ponds = [(dev, info.pond_id) for dev, info in states.items()]

  t = 0
  try:
    while True:
      for dev, pond_id in ponds:
        payload = make_sample(dev, pond_id, t)
        body = json.dumps(payload)
        client.publish(TOPIC, body, qos=0, retain=False)
        client.publish(f"{POND_TOPIC_PREFIX}/{pond_id}/telemetry", body, qos=0, retain=False)
        print(f"[MQTT] {TOPIC} <- {body}")
      t += 1
      time.sleep(3.0)
  except KeyboardInterrupt:
    print("Stopping simulation...")
  finally:
    client.loop_stop()
    client.disconnect()


if __name__ == "__main__":
  main()

