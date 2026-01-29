import asyncio
import serial
import websockets
import json
import time
import sys

# ==========================================
# 1. CONFIGURACIÓN
# ==========================================
ARDUINO_PORT = 'COM5'  # O '/dev/ttyUSB0' en Linux
BAUD_RATE = 9600
WS_PORT = 8080                 # El puerto donde Godot se conectará

# MAPA DE SENSORES
# Mapea el nombre físico del lector al tipo de residuo en el juego
MAPA_SENSORES = {
    "Lector 3": "papel",
    "Lector 2": "plastico",
    "Lector 1": "organico"
}

# Variable para guardar los clientes conectados (Godot)
connected_clients = set()

# ==========================================
# 2. LÓGICA DE WEBSOCKET (SERVIDOR)
# ==========================================
async def handler(websocket):
    """Maneja las conexiones nuevas desde Godot"""
    print(f"✅ Godot se ha conectado desde {websocket.remote_address}")
    connected_clients.add(websocket)
    try:
        await websocket.wait_closed()
    finally:
        print("❌ Godot se desconectó")
        connected_clients.remove(websocket)

async def broadcast_to_godot(data_dict):
    """Envía un diccionario JSON a todos los clientes conectados (Godot)"""
    if not connected_clients:
        print(f"⚠️ Dato recibido ({data_dict['tacho_seleccionado']}), pero Godot no está conectado.")
        return

    message = json.dumps(data_dict)
    print(f"📤 Enviando a Godot: {message}")
    
    # Crear tareas de envío para todos los clientes conectados
    background_tasks = set()
    for ws in connected_clients:
        task = asyncio.create_task(ws.send(message))
        background_tasks.add(task)
        task.add_done_callback(background_tasks.discard)

# ==========================================
# 3. LÓGICA DE PUERTO SERIAL (ARDUINO)
# ==========================================
def iniciar_serial():
    try:
        ser = serial.Serial(ARDUINO_PORT, BAUD_RATE, timeout=0.1) # Timeout bajo para no bloquear
        print(f"✅ Puerto {ARDUINO_PORT} abierto correctamente.")
        time.sleep(2) # Espera reinicio Arduino
        return ser
    except Exception as e:
        print(f"❌ ERROR CRÍTICO abriendo puerto serial: {e}")
        sys.exit()

async def serial_reader(ser):
    """Lee el puerto serial en un bucle infinito no bloqueante"""
    print("🎧 Escuchando Arduino y esperando a Godot...")
    
    while True:
        # Usamos asyncio.sleep para ceder el control y permitir que el WebSocket funcione
        await asyncio.sleep(0.01) 
        
        if ser.in_waiting > 0:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                
                # Buscamos formato "LectorX:UID"
                if ":" in line:
                    partes = line.split(":")
                    if len(partes) >= 2:
                        nombre_lector = partes[0].strip() # Ej: "Lector 3"
                        uid_crudo = partes[1].strip()     # Ej: "04 A1..."

                        # --- A. FORMATEO DE UID ---
                        # Convertir "04A1B2" a "04 A1 B2" (Si es necesario para tu lógica de Godot)
                        uid_formateado = ' '.join(uid_crudo[i:i + 2] for i in range(0, len(uid_crudo), 2))

                        # --- B. MAPEO (TRADUCCIÓN) ---
                        # Convertir "Lector 3" a "papel"
                        tacho_traducido = MAPA_SENSORES.get(nombre_lector)

                        if tacho_traducido:
                            print(f"\n[DETECTADO] {nombre_lector} ({tacho_traducido}) -> UID: {uid_formateado}")
                            
                            # --- C. PREPARAR PAQUETE PARA GODOT ---
                            payload = {
                                "uid": f"pkt_{int(time.time()*1000)}",
                                "id_residuo": uid_formateado,     # Godot espera 'id_residuo'
                                "tacho_seleccionado": tacho_traducido 
                            }
                            
                            # --- D. ENVIAR ---
                            await broadcast_to_godot(payload)
                        else:
                            print(f"⚠️ Sensor desconocido: {nombre_lector}. Revisa MAPA_SENSORES.")
                
                elif line:
                    # Log de mensajes de debug del Arduino
                    print(f"[ARDUINO]: {line}")

            except Exception as e:
                print(f"Error leyendo serial: {e}")

# ==========================================
# 4. EJECUCIÓN PRINCIPAL
# ==========================================
async def main():
    # 1. Iniciar Serial
    ser = iniciar_serial()
    
    # 2. Iniciar Servidor WebSocket (Async)
    async with websockets.serve(handler, "localhost", WS_PORT):
        print(f"🟦 Servidor WebSocket escuchando en ws://localhost:{WS_PORT}")
        
        # 3. Correr el lector serial en paralelo
        await serial_reader(ser)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n--- Servidor Detenido ---")