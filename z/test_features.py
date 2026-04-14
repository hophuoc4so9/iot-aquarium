#!/usr/bin/env python3
"""Test AI features: alerts, forecast, disease prediction."""

import requests
import json

BASE_URL = "http://localhost:8080"  # Backend URL
AI_URL = "http://localhost:8000"     # AI service URL

def test_alerts(pond_id: int):
    """Test water quality alerts."""
    url = f"{BASE_URL}/api/ai/ponds/{pond_id}/alerts"
    try:
        response = requests.get(url, timeout=5)
        print(f"\n✓ Alerts for Pond {pond_id} (Status: {response.status_code})")
        if response.ok:
            data = response.json()
            print(json.dumps(data, indent=2))
            return data
        else:
            print(f"✗ Error: {response.text}")
            return None
    except Exception as e:
        print(f"✗ Connection Error: {e}")
        return None

def test_forecast(pond_id: int, metric: str = "TEMP", hours: int = 1):
    """Test forecast endpoint."""
    url = f"{BASE_URL}/api/ai/forecast"
    params = {
        "pondId": pond_id,
        "metric": metric,
        "horizonHours": hours
    }
    try:
        response = requests.get(url, params=params, timeout=5)
        print(f"\n✓ Forecast for Pond {pond_id}, {metric} (Status: {response.status_code})")
        if response.ok:
            data = response.json()
            print(json.dumps(data, indent=2))
            return data
        else:
            print(f"✗ Error: {response.text}")
            return None
    except Exception as e:
        print(f"✗ Connection Error: {e}")
        return None

def test_fl_models():
    """Test federated learning models endpoint."""
    url = f"{AI_URL}/fl/models/latest"
    try:
        response = requests.get(url, timeout=5)
        print(f"\n✓ FL Latest Model (Status: {response.status_code})")
        if response.ok:
            data = response.json()
            print(json.dumps(data, indent=2))
            return data
        else:
            print(f"✗ Error: {response.text}")
            return None
    except Exception as e:
        print(f"✗ Connection Error: {e}")
        return None

if __name__ == "__main__":
    print("=" * 60)
    print("Testing AI Prediction & Alert Features")
    print("=" * 60)
    
    print("\n[1] Testing Federated Learning Model")
    print("-" * 60)
    test_fl_models()
    
    print("\n[2] Testing Water Quality Alerts")
    print("-" * 60)
    print("Testing Pond 1, 2, 3...")
    for pond_id in [1, 2, 3]:
        test_alerts(pond_id)
    
    print("\n[3] Testing Forecast")
    print("-" * 60)
    print("Testing Temperature Forecast (1 hour)...")
    test_forecast(1, "TEMP", 1)
    print("Testing pH Forecast (1 hour)...")
    test_forecast(1, "PH", 1)
    
    print("\n" + "=" * 60)
    print("Testing Complete!")
    print("=" * 60)
