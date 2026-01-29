from fastapi import FastAPI, HTTPException
# from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import pandas as pd
import uvicorn

app = FastAPI()

#app.add_middleware(
#        CORSMiddleware,
#        allow_origins=["*"],
#        allow_credentials=True,
#        allow_methods=["*"],
#        allow_headers=["*"]
#)

# --- CONFIGURACIÓN ---
MODELO = None
RUTA_MODELO = './modelo_ml/modelo_juego_svm_v2.pkl' 

# --- BASE DE DATOS DE NIVELES (Traída de tu main.py antiguo) ---
# Esto permite que Godot sepa EXACTAMENTE qué basuras spawnear
CONFIGURACION_NIVELES = {
    "bajo": {
        "tiempo_limite": 90,
        "velocidad_aparicion": 2.0,
        "intentos_clasico": 15, # Agregado para modo clásico
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
        "intentos_clasico": 10,
        "set_residuos": [
            { "id": "04 01 9E 48 2A 02 89", "nombre": "Envase de Comida" },
            { "id": "04 11 59 39 2A 02 89", "nombre": "Envase de Yogurt" },
            { "id": "04 61 30 41 2A 02 89", "nombre": "Envase de Shampoo" },
            { "id": "04 91 B5 46 2A 02 89", "nombre": "Botella Aceite" },
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
        "intentos_clasico": 7,
        "set_residuos": [
            { "id": "04 B1 51 4C 2A 02 89", "nombre": "Envases Limpieza" },
            { "id": "04 D1 36 41 2A 02 89", "nombre": "Envase Detergente" },
            { "id": "04 01 9E 48 2A 02 89", "nombre": "Envase Comida" },
            { "id": "04 11 59 39 2A 02 89", "nombre": "Envase de Yogurt" },
            { "id": "04 91 B5 46 2A 02 89", "nombre": "Botella Aceite" },
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

# 1. Recibimos los datos con los nombres BIEN escritos desde Godot
class DatosJuego(BaseModel):
    total_aciertos: int
    total_intentos: int
    precision_jugador: float  
    puntaje_jugador: int
    tiempo_nivel: str
    tipo_nivel: str
    completo_tutorial: str    

@app.on_event("startup")
def load_model():
    global MODELO
    try:
        MODELO = joblib.load(RUTA_MODELO)
        print(f"✅ Modelo cargado: {RUTA_MODELO}")
    except Exception as e:
        print(f"❌ Error carga modelo: {e}")

def tiempo_a_segundos(t):
    try:
        h, m, s = map(int, t.split(':'))
        return h * 3600 + m * 60 + s
    except ValueError:
        return 0

# Función actualizada para usar tu diccionario real
def obtener_configuracion_nivel(perfil):
    # Buscamos en el diccionario, si no existe el perfil, devolvemos 'medio' por defecto
    config_raw = CONFIGURACION_NIVELES.get(perfil, CONFIGURACION_NIVELES["medio"])
    
    # Formateamos para Godot
    return {
        "parametros": {
            "tiempo_limite_segundos": config_raw["tiempo_limite"],
            "velocidad_spawn": config_raw["velocidad_aparicion"],
            "intentos_clasico": config_raw.get("intentos_clasico", 10)
        },
        "assets_residuos": config_raw["set_residuos"]
    }

@app.post("/predecir")
def predecir_rendimiento(datos: DatosJuego):
    if MODELO is None:
        raise HTTPException(status_code=500, detail="Modelo no cargado")

    try:
        d = datos.dict()

        # Conversiones
        tiempo_sec = tiempo_a_segundos(d['tiempo_nivel'])
        tutorial_bin = 1 if d['completo_tutorial'].lower() == "true" else 0

        # --- TRADUCCIÓN PARA EL MODELO .PKL ---
        # El modelo fue entrenado con 'presicion' y 'totorial', así que mapeamos aquí
        input_df = pd.DataFrame([{
            'total_aciertos': d['total_aciertos'],
            'total_intentos': d['total_intentos'],
            'presicion_jugador': d['precision_jugador'],    # <--- Hack para el modelo
            'puntaje_jugador': d['puntaje_jugador'],
            'tiempo_seconds': tiempo_sec,
            'tipo_nivel': d['tipo_nivel'],
            'completo_totorial': tutorial_bin               # <--- Hack para el modelo
        }])

        # Predicción
        prediccion = MODELO.predict(input_df)[0]
        # Convertir a string minúscula para coincidir con las llaves del diccionario ("alto", "medio")
        prediccion_str = str(prediccion).lower() 
        
        # Probabilidades
        probs = MODELO.predict_proba(input_df)[0]
        confianza = {str(c): float(p) for c, p in zip(MODELO.classes_, probs)}

        # Respuesta Completa para Godot
        return {
            "jugador": {
                "perfil_predicho": prediccion_str,
                "confianza": confianza
            },
            # Aquí es donde ocurre la magia: enviamos los items específicos
            "configuracion_nivel_siguiente": obtener_configuracion_nivel(prediccion_str)
        }

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
