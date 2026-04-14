#!/usr/bin/env python3
"""Create initial global FL model for testing."""

import requests
import json

def create_global_model():
    url = "http://localhost:8000/fl/models/register"
    payload = {
        "roundId": 0,
        "weights": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
        "shape": [2, 4],
        "activate": True
    }
    
    try:
        response = requests.post(url, json=payload)
        print(f"✓ Status Code: {response.status_code}")
        print(f"✓ Response: {json.dumps(response.json(), indent=2)}")
        return response.json()
    except Exception as e:
        print(f"✗ Error: {e}")
        return None

if __name__ == "__main__":
    print("Creating initial global FL model...")
    result = create_global_model()
    if result and result.get("status") == "ACTIVE":
        print("\n✓ Global model created and activated successfully!")
    else:
        print("\n? Check response above")
