import json
import random
import time

import paho.mqtt.client as mqtt


BROKER_HOST = "broker.emqx.io"
BROKER_PORT = 1883
TOPIC = "esp32/telemetry"


def make_sample(device_id: str, pond_id: int, t: int) -> dict:
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


def main():
  client = mqtt.Client()
  print(f"Connecting to MQTT broker {BROKER_HOST}:{BROKER_PORT} ...")
  client.connect(BROKER_HOST, BROKER_PORT, keepalive=60)
  client.loop_start()

  ponds = [
    ("esp32-aquarium-001", 1),
    ("esp32-aquarium-002", 2),
    ("esp32-aquarium-003", 3),
  ]

  t = 0
  try:
    while True:
      for dev, pond_id in ponds:
        payload = make_sample(dev, pond_id, t)
        body = json.dumps(payload)
        client.publish(TOPIC, body, qos=0, retain=False)
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

