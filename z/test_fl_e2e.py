#!/usr/bin/env python3
"""
End-to-End FL System Test
Simulates: Start → Train → Aggregate → Activate
"""

import json
import requests
import time
from dataclasses import dataclass

@dataclass
class TestConfig:
    backend_url: str = "http://localhost:8080/api"
    ai_service_url: str = "http://localhost:8000"
    roundId: int = 999
    deviceIds: list = None
    
    def __post_init__(self):
        if self.deviceIds is None:
            self.deviceIds = [5, 6]

def test_fl_e2e():
    config = TestConfig()
    print("=" * 70)
    print("🚀 FEDERATED LEARNING E2E TEST")
    print("=" * 70)
    
    # 1. Start Round
    print("\n1️⃣ Starting FL round...")
    try:
        resp = requests.post(
            f"{config.backend_url}/fl/rounds/start",
            json={
                "roundId": config.roundId,
                "deadlineSeconds": 120,
                "minClients": 2,
                "minSamples": 1,
                "deviceIds": config.deviceIds,
                "epochs": 1,
                "samples": 16
            },
            timeout=10
        )
        assert resp.status_code == 200, f"Start failed: {resp.status_code} {resp.text}"
        result = resp.json()
        print(f"✅ Round started: {result['roundId']}")
        print(f"   Target devices: {result['targetDeviceIds']}")
    except Exception as e:
        print(f"❌ Start failed: {e}")
        return False
    
    # 2. Check online devices
    print("\n2️⃣ Checking online devices...")
    try:
        resp = requests.get(f"{config.backend_url}/fl/devices/online", timeout=5)
        assert resp.status_code == 200
        result = resp.json()
        print(f"✅ Online devices: {result['count']}")
        for device in result['items'][:3]:
            print(f"   - Device {device['deviceId']}: {device['secondsSinceLastTelemetry']}s ago")
    except Exception as e:
        print(f"⚠️  Online check failed (simulator may not have data yet): {e}")
    
    # 3. Simulate client updates (mock device training)
    print("\n3️⃣ Simulating device training & reports...")
    try:
        for device_id in config.deviceIds:
            # Post client update
            update = {
                "deviceId": device_id,
                "pondId": device_id,
                "roundId": config.roundId,
                "sampleCount": 10,
                "loss": 0.05,
                "weights": [0.1, 0.2, 0.15, 0.05, 0.8, 0.02, 0.02, 0.02],
                "shape": [8]
            }
            resp = requests.post(
                f"{config.backend_url}/fl/updates",
                json=update,
                timeout=5
            )
            assert resp.status_code == 200, f"Update failed: {resp.text}"
            print(f"✅ Device {device_id} uploaded update")
        time.sleep(1)
    except Exception as e:
        print(f"❌ Update failed: {e}")
        return False
    
    # 4. Get round stats before aggregation
    print("\n4️⃣ Checking round statistics...")
    try:
        resp = requests.get(f"{config.backend_url}/fl/rounds/{config.roundId}/stats", timeout=5)
        assert resp.status_code == 200, f"Stats failed: {resp.status_code}"
        stats = resp.json()
        print(f"✅ Round stats:")
        print(f"   Status: {stats['status']}")
        print(f"   Target devices: {stats['targetDeviceCount']}")
        print(f"   Updated devices: {stats['updatedDeviceCount']}")
        print(f"   Pending: {stats['pendingDeviceCount']}")
        assert stats['updatedDeviceCount'] == 2, "Not all devices reported"
    except Exception as e:
        print(f"❌ Stats check failed: {e}")
        return False
    
    # 5. Aggregate round
    print("\n5️⃣ Aggregating models...")
    try:
        resp = requests.post(
            f"{config.backend_url}/fl/rounds/{config.roundId}/aggregate",
            timeout=10
        )
        assert resp.status_code == 200, f"Aggregate failed: {resp.status_code} {resp.text}"
        result = resp.json()
        print(f"✅ Aggregation successful:")
        print(f"   Version: {result.get('version')}")
        print(f"   Num clients: {result.get('numClients')}")
        print(f"   Total samples: {result.get('totalSamples')}")
        print(f"   Checksum: {result.get('checksum')}")
    except Exception as e:
        print(f"❌ Aggregation failed: {e}")
        return False
    
    # 6. Get latest model
    print("\n6️⃣ Retrieving latest model...")
    try:
        resp = requests.get(f"{config.backend_url}/fl/models/latest", timeout=5)
        assert resp.status_code == 200, f"Model fetch failed: {resp.status_code}"
        model = resp.json()
        print(f"✅ Latest model retrieved:")
        print(f"   Version: {model.get('version')}")
        print(f"   Status: {model.get('status')}")
        print(f"   Round: {model.get('roundId')}")
        weights = model.get('payload', {}).get('weights', [])
        print(f"   Weights ({len(weights)} dims): {[f'{w:.4f}' for w in weights[:3]]}...")
    except Exception as e:
        print(f"❌ Model fetch failed: {e}")
        return False
    
    # 7. Verify round final status
    print("\n7️⃣ Verifying round completion...")
    try:
        resp = requests.get(f"{config.backend_url}/fl/rounds/{config.roundId}", timeout=5)
        assert resp.status_code == 200
        round_info = resp.json()
        print(f"✅ Round complete:")
        print(f"   Status: {round_info['status']}")
        print(f"   Aggregated version: {round_info.get('aggregatedVersion')}")
        print(f"   Created: {round_info['createdAt']}")
        print(f"   Aggregated: {round_info.get('aggregatedAt')}")
        assert round_info['status'] == 'AGGREGATED', "Round not aggregated"
    except Exception as e:
        print(f"❌ Round status check failed: {e}")
        return False
    
    # 8. List rounds history
    print("\n8️⃣ Listing rounds history...")
    try:
        resp = requests.get(
            f"{config.backend_url}/fl/rounds/history",
            params={"status": "AGGREGATED", "page": 0, "size": 10},
            timeout=5
        )
        assert resp.status_code == 200
        history = resp.json()
        print(f"✅ Rounds history: {history['totalItems']} total rounds")
        if history['items']:
            latest = history['items'][0]
            print(f"   Latest: Round {latest['roundId']} ({latest['status']})")
    except Exception as e:
        print(f"❌ History check failed: {e}")
        return False
    
    print("\n" + "=" * 70)
    print("✅ ALL TESTS PASSED - FL SYSTEM WORKING END-TO-END!")
    print("=" * 70)
    return True

if __name__ == "__main__":
    import sys
    success = test_fl_e2e()
    sys.exit(0 if success else 1)
