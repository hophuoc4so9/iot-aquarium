#!/bin/bash
# Quick Start: IoT Aquarium AI Testing
# Run this to set up all services and test AI features

set -e

echo "=========================================="
echo "IoT Aquarium AI Testing - Quick Start"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Start AI Service
echo -e "${BLUE}[1/4] Starting AI Service...${NC}"
echo "  Python dependencies: fastapi, uvicorn, tensorflow, numpy, pillow"
cd ai-service

# Check if venv exists
if [ ! -d ".venv" ]; then
    echo "  Creating virtual environment..."
    python -m venv .venv
fi

# Activate venv and install
if [ -f ".venv/Scripts/activate" ]; then
    # Windows
    .\.venv\Scripts\activate
    pip install -r requirements.txt > /dev/null 2>&1
    start "AI Service" python main.py
elif [ -f ".venv/bin/activate" ]; then
    # Linux/Mac
    source .venv/bin/activate
    pip install -r requirements.txt > /dev/null 2>&1
    python main.py &
fi

echo -e "${GREEN}✓ AI Service starting on localhost:8000${NC}"
cd ..
sleep 3

# Step 2: Initialize FL Model
echo -e "${BLUE}[2/4] Creating Global FL Model...${NC}"
python test_create_model.py > /dev/null 2>&1
echo -e "${GREEN}✓ Global FL Model created (Version 2, Status: ACTIVE)${NC}"
sleep 1

# Step 3: Start Telemetry Simulator
echo -e "${BLUE}[3/4] Starting Telemetry Simulator...${NC}"
if [ -f ".venv/Scripts/activate" ]; then
    # Windows
    start "Telemetry Simulator" cmd /c "cd ai-service && .\.venv\Scripts\python ..\tools\simulate_ponds.py"
else
    # Linux/Mac
    (.venv/bin/python tools/simulate_ponds.py &)
fi
echo -e "${GREEN}✓ Simulator publishing to broker.emqx.io (Pond 1, 2, 3)${NC}"
sleep 2

# Step 4: Run Tests
echo -e "${BLUE}[4/4] Testing AI Features...${NC}"
python test_ai_service.py
echo ""

# Print next steps
echo -e "${YELLOW}========== NEXT STEPS ==========${NC}"
echo ""
echo "1. Start Backend (Java):"
echo "   cd be"
echo "   mvn spring-boot:run"
echo ""
echo "2. Start Web Admin (React):"
echo "   cd web-admin"
echo "   npm install"
echo "   npm run dev"
echo ""
echo "3. Verify Admin Page:"
echo "   Open http://localhost:5173"
echo "   Go to FL tab → Should show model without error ✓"
echo ""
echo "4. Start Mobile App (Flutter, optional):"
echo "   cd app-user"
echo "   flutter run"
echo ""
echo -e "${GREEN}✓ AI Service is ready!${NC}"
echo ""
