cd iot


🚀 1. Build project
python -m platformio run




🔌 3. Upload code
python -m platformio run -t upload


🖥️ 4. Serial monitor
python -m platformio device monitor


🔄 5. Upload + monitor 


python -m platformio run -t upload -t monitor


🧹 6. Clean build
python -m platformio run -t clean