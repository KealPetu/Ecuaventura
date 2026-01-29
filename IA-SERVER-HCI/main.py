from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import pandas as pd
import uvicorn
import os
from fastapi import Request
import datetime
import requests

# ==============================
# Configuración
# ==============================
RUTA_MODELO = "./Model/modelo_juego_svm_v2.pkl"  # Asegúrate que esta ruta es real en tu PC
RUTA_DATASET = "./Debug/datos_juego.csv"
MODELO = None

MAPA_RESIDUOS = {
    "04 B1 51 4C 2A 02 89": "plastico",
    "04 01 9E 48 2A 02 89": "organico",
    "04 11 59 39 2A 02 89": "papel",
    "04 61 30 41 2A 02 89": "papel",
    "04 D1 36 41 2A 02 89": "organico",
    "04 91 B5 46 2A 02 89": "plastico",
    "04 41 9C F9 29 02 89": "papel",
    "04 41 6F 4A 2A 02 89": "papel",
    "04 81 B4 4A 2A 02 89": "plastico",
    "04 11 DE 4A 2A 02 89": "organico",
    "04 B1 56 4C 2A 02 89": "papel",
    "04 31 6D 3C 2A 02 89": "papel",
    "04 71 9C 47 2A 02 89": "plastico",
    "04 81 9C 45 2A 02 89": "organico",
    "04 C1 FD 03 2A 02 89": "plastico",
    "04 B1 AD 3B 2A 02 89": "organico",
    "04 71 00 FC 29 02 89": "papel",
    "04 81 19 47 2A 02 89": "papel",
    "04 F1 14 49 2A 02 89": "organico",
    "04 61 30 45 2A 02 89": "plastico",
    "04 C1 5B 01 2A 02 89": "papel",
    "04 11 91 40 2A 02 89": "papel",
    "04 01 27 3D 2A 02 89": "plastico",
    "04 01 DB C4 29 02 89": "organico",
    "04 81 1C 46 2A 02 89": "papel",
    "04 C1 BE 3B 2A 02 89": "papel",
    "04 71 F1 42 2A 02 89": "plastico",
    "04 31 E0 3D 2A 02 89": "organico",
    "04 A1 B3 3B 2A 02 89": "plastico",
    "04 41 E2 48 2A 02 89": "organico"
}

CONFIGURACION_NIVELES = {
    "bajo": {
        "tiempo_limite": 90,
        "velocidad_aparicion": 2.0,
        "margen_error_visual": 0.0,
        "set_residuos": [
  { "id": "04 41 6F 4A 2A 02 89", "nombre": "Botella de Agua" },
  { "id": "04 41 9C F9 29 02 89", "nombre": "Botella de Gaseosa" },
  { "id": "04 81 B4 4A 2A 02 89", "nombre": "Bolsa de Plástico" },
  { "id": "04 F1 14 49 2A 02 89", "nombre": "Cartón" },
  { "id": "04 71 9C 47 2A 02 89", "nombre": "Periódicos" },
  { "id": "04 81 9C 45 2A 02 89", "nombre": "Hojas Usadas" },
  { "id": "04 A1 B3 3B 2A 02 89", "nombre": "Cascara de Platano" },
  { "id": "04 31 E0 3D 2A 02 89", "nombre": "Cascaras de Huevo" },
  { "id": "04 C1 5B 01 2A 02 89", "nombre": "Restos de Verduras" },
  { "id": "04 81 1C 46 2A 02 89", "nombre": "Pan Viejo" }
]
    },
    "medio": {
        "tiempo_limite": 60,
        "velocidad_aparicion": 1.5,
        "margen_error_visual": 0.3,
        "set_residuos": [
  { "id": "04 01 9E 48 2A 02 89", "nombre": "Envase de Comida para Llevar" },
  { "id": "04 11 59 39 2A 02 89", "nombre": "Envase de Yogurt" },
  { "id": "04 61 30 41 2A 02 89", "nombre": "Envase de Shampoo" },
  { "id": "04 91 B5 46 2A 02 89", "nombre": "Botella de Aceite de Cocina" },
  { "id": "04 61 30 45 2A 02 89", "nombre": "Bolsas de Papel" },
  { "id": "04 B1 56 4C 2A 02 89", "nombre": "Sobre de Papel" },
  { "id": "04 31 6D 3C 2A 02 89", "nombre": "Revistas Viejas" },
  { "id": "04 71 00 FC 29 02 89", "nombre": "Papel de Embalaje" },
  { "id": "04 81 19 47 2A 02 89", "nombre": "Cartón de Huevos" },
  { "id": "04 01 27 3D 2A 02 89", "nombre": "Restos de Café" },
  { "id": "04 41 E2 48 2A 02 89", "nombre": "Bolsa de Te Usada" },
  { "id": "04 71 F1 42 2A 02 89", "nombre": "Cascaras de Papa" },
  { "id": "04 C1 BE 3B 2A 02 89", "nombre": "Manzana y Pera" },
  { "id": "04 41 6F 4A 2A 02 89", "nombre": "Botella de Agua" },
  { "id": "04 F1 14 49 2A 02 89", "nombre": "Cartón" }
]
    },
    "alto": {
        "tiempo_limite": 40,
        "velocidad_aparicion": 0.8,
        "margen_error_visual": 0.8,
        "set_residuos": [
  { "id": "04 B1 51 4C 2A 02 89", "nombre": "Envases de Productos de Limpieza" },
  { "id": "04 D1 36 41 2A 02 89", "nombre": "Envase de Detergente" },
  { "id": "04 01 9E 48 2A 02 89", "nombre": "Envase de Comida para Llevar" },
  { "id": "04 11 59 39 2A 02 89", "nombre": "Envase de Yogurt" },
  { "id": "04 91 B5 46 2A 02 89", "nombre": "Botella de Aceite de Cocina" },
  { "id": "04 B1 AD 3B 2A 02 89", "nombre": "Folletos"},
  { "id": "04 71 00 FC 29 02 89", "nombre": "Papel de Embalaje" },
  { "id": "04 81 19 47 2A 02 89", "nombre": "Cartón de Huevos" },
  { "id": "04 C1 FD 03 2A 02 89", "nombre": "Hojas de Impresora" },
  { "id": "04 01 27 3D 2A 02 89", "nombre": "Restos de Café" },
  { "id": "04 01 DB C4 29 02 89", "nombre": "Restos de Arroz" },
  { "id": "04 11 91 40 2A 02 89", "nombre": "Restos de Plantas" },
  { "id": "04 41 E2 48 2A 02 89", "nombre": "Bolsa de Te Usada" },
  { "id": "04 71 F1 42 2A 02 89", "nombre": "Cascaras de Papa" },
  { "id": "04 31 E0 3D 2A 02 89", "nombre": "Cascaras de Huevo" },
  { "id": "04 A1 B3 3B 2A 02 89", "nombre": "Cascara de Platano" },
  { "id": "04 61 30 45 2A 02 89", "nombre": "Bolsas de Papel" },
  { "id": "04 31 6D 3C 2A 02 89", "nombre": "Revistas Viejas" },
  { "id": "04 81 B4 4A 2A 02 89", "nombre": "Bolsa de Plástico" },
  { "id": "04 41 9C F9 29 02 89", "nombre": "Botella de Gaseosa" }
]
    }
}

app = FastAPI(title="EcuAventura IA", version="1.1")

# ==============================
# Modelo de datos (Exactamente igual a tu Postman)
# ==============================
class DatosJuego(BaseModel):
    total_aciertos: int
    total_intentos: int
    presicion_jugador: float  # Nota: mantengo tu error tipográfico 'presicion' para que coincida
    puntaje_jugador: int
    tiempo_nivel: str        # Llega como String "04:56:00"
    tipo_nivel: str          # "aventura", "contra_reloj"
    completo_totorial: bool  # Nota: mantengo 'totorial'

    class Config:
        extra = "allow"
# ==============================
# Modelo de datos para RFID (si es necesario)
# ==============================
class LecturaRFID(BaseModel):
    uid: str
# ==============================
# Cargar Modelo
# ==============================
@app.on_event("startup")
def cargar_modelo():
    global MODELO
    try:
        if os.path.exists(RUTA_MODELO):
            MODELO = joblib.load(RUTA_MODELO)
            print(f"✅ Modelo cargado: {RUTA_MODELO}")
        else:
            print(f"❌ NO se encontró el archivo: {RUTA_MODELO}")
    except Exception as e:
        print(f"❌ Error crítico cargando modelo: {e}")

# ==============================
# Función Auxiliar (La misma que usaste en el test)
# ==============================
def tiempo_a_segundos(t: str) -> int:
    try:
        h, m, s = map(int, t.split(':'))
        return h * 3600 + m * 60 + s
    except Exception:
        # Si falla (ej: formato incorrecto), devolvemos 0 o lanzamos error
        return 0 

# ==============================
# Endpoint Predicción
# ==============================
@app.post("/predecir", tags=["IA"])
def predecir(datos: DatosJuego):
    if MODELO is None:
        raise HTTPException(status_code=503, detail="El modelo no está cargado.")

    try:
        datos_dict = datos.dict()
        input_df = pd.DataFrame([datos_dict])
        input_df['tiempo_seconds'] = input_df['tiempo_nivel'].apply(tiempo_a_segundos)
        if 'completo_totorial' in input_df.columns:
            input_df['completo_totorial'] = input_df['completo_totorial'].astype(int)
        prediccion_raw = MODELO.predict(input_df)[0]
        clase_predicha = str(prediccion_raw).lower()
        
        probs_dict = {}
        if hasattr(MODELO, "predict_proba"):
            probs = MODELO.predict_proba(input_df)[0]
            probs_dict = {
                str(c): f"{p * 100:.2f}%" for c, p in zip(MODELO.classes_, probs)
            }
        
        config_nivel = CONFIGURACION_NIVELES.get(clase_predicha, CONFIGURACION_NIVELES["medio"])
        
        return {
            "jugador": {
                "perfil_predicho": clase_predicha,
                "confianza": probs_dict
            },
            "configuracion_nivel_siguiente": {
                "descripcion": f"Nivel adaptado para perfil {clase_predicha}",
                "parametros": {
                    "tiempo_limite_segundos": config_nivel["tiempo_limite"],
                    "velocidad_spawn": config_nivel["velocidad_aparicion"]
                },
                "assets_residuos": config_nivel["set_residuos"]
            }
        }

    except Exception as e:
        print(f"Error detallado: {e}")
        raise HTTPException(status_code=500, detail=f"Error en predicción: {str(e)}")

# 2. Endpoint optimizado para recibir SOLO el UID
@app.post("/webhook_debug", tags=["Debug"])
def recibir_lectura_arduino(dato: LecturaRFID):
    try:
        # 1. Definimos la variable PRIMERO
        texto_recibido = dato.uid.strip()
        tacho_recibido = dato.sensor.strip()
        print(f"📥 Recibido raw: {texto_recibido} & {tacho_recibido}") 

        # 2. LIMPIEZA INTELIGENTE
        if "Card UID:" in texto_recibido:
            uid_limpio = texto_recibido.replace("Card UID:", "").strip()
        else:
            uid_limpio = texto_recibido
            
        # 3. VALIDACIÓN BÁSICA
        if not uid_limpio or uid_limpio == "Listo":
             return {"status": "ignored", "motivo": "Mensaje vacío o de sistema"}

        # 4. TRADUCCIÓN
        nombre_objeto = MAPA_RESIDUOS.get(uid_limpio, "objeto_desconocido")

        # 5. GUARDADO EN CSV
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        os.makedirs(os.path.dirname(RUTA_DATASET), exist_ok=True)

        with open(RUTA_DATASET, "a", encoding="utf-8") as f:
            if os.path.getsize(RUTA_DATASET) == 0:
                f.write("Timestamp,UID_Hex,Objeto_Detectado\n")
            f.write(f"{timestamp},{uid_limpio},{nombre_objeto}\n")

        print(f"✅ Guardado CSV: {nombre_objeto} ({uid_limpio})")
        
        # ---------------------------------------------------------
        # 6. REENVÍO A LA UI (NODE.JS) - ¡NUEVO!
        # --------------------------------------------------- ------
        try:
            #url_node = "https://pseudohumanistic-incompletely-derick.ngrok-free.dev/webhook"
            url_node = "https://pseudohumanistic-incompletely-derick.ngrok-free.dev/sensor-data"
            payload_node = {
                "id_residuo": uid_limpio,
                "tacho": tacho_recibido
                }
            
            # timeout=0.5 es importante para que si Node se cae, 
            # tu API de Python no se quede congelada esperando.
            requests.post(url_node, json=payload_node, timeout=0.5)
            print(f"✨ Enviado a UI (Node.js)")
            
        except requests.exceptions.ConnectionError:
            print("⚠️ No se pudo conectar con la UI (Node.js no está corriendo)")
        except Exception as e:
            print(f"⚠️ Error enviando a UI: {e}")
        # ---------------------------------------------------------

        return {
            "status": "ok", 
            "uid": uid_limpio, 
            "objeto": nombre_objeto
        }

    except Exception as e:
        print(f"❌ Error en endpoint: {e}")
        return {"status": "error", "detalle": str(e)}
    
if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)