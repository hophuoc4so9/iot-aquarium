#!/usr/bin/env python3
"""Test AI features directly from AI service."""

import requests
import json
import time

AI_URL = "http://localhost:8000"  # AI service URL

def test_fl_models():
    """Test federated learning models endpoint."""
    print("\n[1] FL Latest Model")
    url = f"{AI_URL}/fl/models/latest"
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Status: {response.status_code}")
            print(f"  Version: {data['version']}")
            print(f"  Status: {data['status']}")
            print(f"  RoundId: {data['roundId']}")
            print(f"  Weights shape: {data['payload']['shape']}")
            return data
        else:
            print(f"✗ Status: {response.status_code}")
            print(f"  {response.text}")
    except Exception as e:
        print(f"✗ Error: {e}")
    return None

def test_ponds_alerts():
    """Test water quality alerts via AI service."""
    print("\n[2] Water Quality Alerts (from AI Service)")
    # First, need to register ponds/telemetry with the AI service
    # This endpoint evaluates the latest telemetry
    url = f"{AI_URL}/ponds/1/alerts"
    try:
        # POST request to get alerts
        response = requests.post(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Status: {response.status_code}")
            print(f"  Pond: {data.get('pondId')}")
            print(f"  Alerts: {json.dumps(data.get('alerts', []), indent=4)}")
            return data
        else:
            print(f"✗ Status: {response.status_code}")
            print(f"  {response.text}")
    except Exception as e:
        print(f"✗ Error: {e}")
    return None

def test_forecast():
    """Test temperature/pH forecast."""
    print("\n[3] Forecast (Temperature & pH)")
    for metric in ["TEMP", "PH"]:
        url = f"{AI_URL}/forecast"
        params = {
            "pondId": 1,
            "metric": metric,
            "horizonHours": 3
        }
        try:
            response = requests.post(url, params=params, timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"✓ {metric} Forecast (Status: {response.status_code})")
                if "forecast" in data:
                    print(f"  Values: {data['forecast'][:3]}...")  # Show first 3 values
                else:
                    print(f"  Response: {json.dumps(data, indent=4)}")
                return data
            else:
                print(f"✗ {metric} Forecast (Status: {response.status_code})")
                print(f"  {response.text}")
        except Exception as e:
            print(f"✗ {metric} Forecast Error: {e}")
    return None

def test_fl_get_status():
    """Test FL model status endpoint."""
    print("\n[4] FL Model Status")
    url = f"{AI_URL}/fl/models/1"
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Status: {response.status_code}")
            print(f"  Model Version: {data.get('version')}")
            print(f"  Model Status: {data.get('status')}")
            return data
        else:
            print(f"✗ Status: {response.status_code}")
            if response.status_code == 404:
                print("  (Model version 1 not found, which is expected)")
    except Exception as e:
        print(f"✗ Error: {e}")
    return None

def test_health():
    """Test AI service health."""
    print("\n[0] AI Service Health Check")
    url = f"{AI_URL}/"
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            print(f"✓ Service is UP")
            print(f"  {json.dumps(response.json(), indent=2)}")
            return True
        else:
            print(f"✗ Service returned {response.status_code}")
    except Exception as e:
        print(f"✗ Service DOWN: {e}")
    return False

if __name__ == "__main__":
    print("=" * 70)
    print("Testing AI Service - Prediction & Alert Features")
    print("=" * 70)
    
    if not test_health():
        print("\n✗ AI Service is not accessible. Please start it first.")
        print("  Command: python ai-service/main.py")
        exit(1)
    
    # Wait a moment for fresh data
    print("\nWaiting 2 seconds for fresh telemetry...")
    time.sleep(2)
    
    test_fl_models()
    test_ponds_alerts()
    test_forecast()
    test_fl_get_status()
    
    print("\n" + "=" * 70)
    print("✓ Test Complete!")
    print("=" * 70)
