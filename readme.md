Chạy MySQL bằng Docker
docker-compose up -d

1. ai
cd ai-service
py -3.11 -m venv .venv
.\.venv\Scripts\activate
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

2. Chạy Backend (Spring Boot)

cd be
mvn spring-boot:run


Backend chạy ở: http://localhost:8080

API chat bot đã ở http://localhost:8080/api/chat



python E:\Daihoc\nckh-2025\IOT-BeCa\iot-final-aquarium\tools\simulate_ponds.py

3. Chạy Web-admin

cd web-admin
npm run dev


npm install

4. Chạy App-user (Flutter)
cd app-user

flutter run -d chrome


flutter pub get



tk: 
farmer1
123456

admin
123456