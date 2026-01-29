@echo off
TITLE Launcher EcuaVentura
COLOR 0A


echo ==========================================
echo    INICIANDO SISTEMA ECUAVENTURA
echo ==========================================

:: ---------------------------------------------------------
:: PASO 1: GESTIÓN DE DEPENDENCIAS (BLOQUEANTE)
:: ---------------------------------------------------------
echo [1/3] Verificando entorno y dependencias...

:: 1.1 Verificar si existe el entorno virtual, si no, crearlo.
if not exist ".venv" (
    echo    - Creando entorno virtual .venv...
    python -m venv .venv
)

:: 1.2 Instalar/Actualizar dependencias.
:: NOTA: No usamos "start" aquí para obligar al sistema a esperar que termine la instalación.
echo    - Instalando librerias desde requirements.txt...
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

:: 1.3 Verificación de errores
if %ERRORLEVEL% NEQ 0 (
    COLOR 0C
    echo.
    echo [ERROR] Fallo la instalacion de dependencias. Revisa tu conexion o python.
    pause
    exit
)

echo.
echo Dependencias listas. Iniciando servidores...
echo.

:: ---------------------------------------------------------
:: PASO 2: INICIAR SERVIDORES (PARALELO)
:: ---------------------------------------------------------
:: Aquí sí usamos "start" para que se queden abiertos en fondo.

:: 2.1 Servidor ML
echo [2/3] Iniciando Cerebro IA (Puerto 8000)...
start /min "Servidor ML" cmd /k ".\.venv\Scripts\activate && cd backend_ml && uvicorn main:app --host 127.0.0.1 --port 8000"

:: 2.2 Servidor Hardware
echo [2/3] Conectando Sensores (Puerto 8080)...
start /min "Servidor Hardware" cmd /k ".\.venv\Scripts\activate && cd middleware && python main.py"

:: Damos un tiempo de gracia un poco mayor para asegurar que uvicorn arranque
echo    - Esperando que los servidores se estabilicen (5 seg)...
timeout /t 5 /nobreak >nul

:: ---------------------------------------------------------
:: PASO 3: LANZAR JUEGO
:: ---------------------------------------------------------
echo [3/3] Lanzando Juego...
cd juego\build

:: Verificamos que el exe exista antes de intentar abrirlo
if exist "ecuaventura.exe" (
    start "" "ecuaventura.exe"
) else (
    COLOR 0C
    echo [ERROR] No se encuentra ecuaventura.exe en la carpeta juego\build
    pause
)

:: Volver al directorio raíz por si acaso
cd ..\..

echo.
echo ==========================================
echo    SISTEMA EJECUTANDOSE EXITOSAMENTE
echo ==========================================
echo No cierres las ventanas minimizadas de los servidores.
echo Puedes cerrar esta ventana si lo deseas.
pause