Chạy MySQL bằng Docker
docker-compose up -d

1. ai
cd ai-service
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

2. Chạy Backend (Spring Boot)

cd be
# build (lần đầu)
.\mvnw.cmd clean install
# chạy
.\mvnw.cmd spring-boot:run

Backend chạy ở: http://localhost:8080

API chat bot đã ở http://localhost:8080/api/chat



python E:\Daihoc\nckh-2025\IOT-BeCa\iot-final-aquarium\tools\simulate_ponds.py

3. Chạy Web-admin
cd web-admin
npm install
npm run dev

4. Chạy App-user (Flutter)
cd app-user
flutter pub get
flutter run 
flutter run -d chrome


tk: 
farmer1
123456

admin
123456