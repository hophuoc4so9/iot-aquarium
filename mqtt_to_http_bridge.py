import json

import paho.mqtt.client as mqtt
import requests


BROKER_HOST = "broker.emqx.io"
BROKER_PORT = 1883
TOPIC = "esp32/telemetry"

BACKEND_BASE_URL = "http://localhost:8000"
INGEST_PATH = "/telemetry-ingest"


def on_connect(client: mqtt.Client, userdata, flags, rc):
    print(f"[MQTT] Connected with result code {rc}")
    client.subscribe(TOPIC, qos=0)
    print(f"[MQTT] Subscribed to {TOPIC}")


def on_message(client: mqtt.Client, userdata, msg: mqtt.MQTTMessage):
    try:
        payload = json.loads(msg.payload.decode("utf-8"))
    except json.JSONDecodeError as e:
        print(f"[MQTT] Invalid JSON payload: {e}")
        return

    try:
        url = BACKEND_BASE_URL + INGEST_PATH
        resp = requests.post(url, json=payload, timeout=3)
        if resp.status_code == 200:
            print(f"[BRIDGE] OK -> {url} {payload}")
        else:
            print(
                f"[BRIDGE] ERROR {resp.status_code} -> {url}: {resp.text}"
            )
    except Exception as e:
        print(f"[BRIDGE] Failed to send to backend: {e}")


def main():
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    print(f"[MQTT] Connecting to {BROKER_HOST}:{BROKER_PORT} ...")
    client.connect(BROKER_HOST, BROKER_PORT, keepalive=60)

    try:
        client.loop_forever()
    except KeyboardInterrupt:
        print("Stopping bridge...")
        client.disconnect()


if __name__ == "__main__":
    main()

