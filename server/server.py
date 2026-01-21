from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
import uvicorn
import os
import datetime
import asyncio

# --- GESTOR DE CONEXIONES (NUEVO) ---
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print("🎮 Godot conectado")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        print("🔌 Godot desconectado")

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            # Enviamos el mensaje a Godot
            await connection.send_text(message)

manager = ConnectionManager()
# -------------------------------------

RUTA_DATASET = "./debug/datos_juego.csv"

class LecturaRFID(BaseModel):
    uid: str
    
app = FastAPI(title="EcuAventura Server", version="1.2")

# --- ENDPOINT WEBSOCKET PARA GODOT (NUEVO) ---
@app.websocket("/ws/godot")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Mantenemos la conexión viva esperando mensajes (ping/pong)
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# --- TU ENDPOINT EXISTENTE (MODIFICADO) ---
@app.post("/webhook_debug", tags=["Debug"])
async def recibir_lectura_arduino(dato: LecturaRFID): # Nota el 'async' necesario para broadcast
    """
    Recibe JSON, Guarda CSV y AVISA A GODOT
    """
    try:
        uid_limpio = dato.uid.strip()
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # 1. Lógica original: Guardar en CSV
        os.makedirs(os.path.dirname(RUTA_DATASET), exist_ok=True)
        
        with open(RUTA_DATASET, "a", encoding="utf-8") as f:
            if os.path.getsize(RUTA_DATASET) == 0:
                f.write("Timestamp,UID_Leido\n")
            
            uid_safe = uid_limpio.replace(",", ";") 
            f.write(f"{timestamp},{uid_safe}\n")

        print(f"✅ Guardado CSV: {uid_limpio}")

        # 2. NUEVO: Enviar a Godot en tiempo real
        # Enviamos un JSON limpio para que Godot lo entienda fácil
        mensaje_godot = f'{{"action": "rfid", "uid": "{uid_safe}"}}'
        await manager.broadcast(mensaje_godot)
        
        return {"status": "ok", "recibido": uid_limpio, "broadcast": "enviado"}

    except Exception as e:
        print(f"❌ Error: {e}")
        return {"status": "error", "detalle": str(e)}

if __name__ == "__main__":
    # Asegúrate que el nombre del archivo coincida (ej: server.py -> "server:app")
    uvicorn.run("server:app", host="127.0.0.1", port=8000, reload=True)