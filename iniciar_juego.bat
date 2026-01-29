@echo off
TITLE Launcher EcuaVentura
COLOR 0A

echo ==========================================
echo    INICIANDO SISTEMA ECUAVENTURA
echo ==========================================

echo Inicializando entorno...
start /min "Configuracion de entorno..." cmd /k "python -m venv .venv && .\.venv\Scripts\activate && pip install -r requirements.txt && exit"
:: 1. Iniciar Servidor ML
echo [1/3] Iniciando Cerebro IA (Puerto 8000)...
start /min "Servidor ML" cmd /k ".\.venv\Scripts\activate && cd backend_ml && uvicorn main:app --host 127.0.0.1 --port 8000"

:: 2. Iniciar Servidor Hardware
echo [2/3] Conectando Sensores y WebSocket (Puerto 8080)...
start "Servidor Hardware" cmd /k ".\.venv\Scripts\activate && cd middleware && python main.py"

:: Esperar 3 segundos para que los servidores arranquen
timeout /t 3 /nobreak >nul

:: 3. Iniciar Servidor Web para el Juego y abrir navegador
echo [3/3] Lanzando de Juego...
cd juego
cd build

start "" "ecuaventura.exe"

echo.
echo SISTEMA EJECUTANDOSE
echo Cierra esta ventana para detener todo (manual) o cierra los servidores aparte
pause