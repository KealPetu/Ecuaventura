from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import pandas as pd
import uvicorn

# Inicializamos la aplicación
app = FastAPI()

# Variables globales
MODELO = None
RUTA_MODELO = './modelo_ml/modelo_juego_svm.pkl'

# Definimos la estructura de los datos que esperamos recibir de Unity
# Pydantic validará que los datos sean correctos
class DatosJuego(BaseModel):
    tiempo_nivel: str  # Formato esperado "HH:MM:SS"
    # Aquí puedes agregar más campos si tu modelo los necesita, por ejemplo:
    # puntuacion: int
    # vidas_restantes: int
    
    class Config:
        # Esto permite enviar campos extra que no estén definidos explícitamente arriba
        # (Útil si tu modelo usa muchas variables y no quieres escribirlas todas aquí)
        extra = "allow" 

# --- Carga del modelo al iniciar el servidor ---
@app.on_event("startup")
def load_model():
    global MODELO
    try:
        MODELO = joblib.load(RUTA_MODELO)
        print(f"✅ Modelo cargado exitosamente desde: {RUTA_MODELO}")
    except FileNotFoundError:
        print(f"❌ Error: No se encontró el archivo '{RUTA_MODELO}'")
    except Exception as e:
        print(f"❌ Error al cargar el modelo: {e}")

# --- Función auxiliar de tiempo ---
def tiempo_a_segundos(t):
    try:
        h, m, s = map(int, t.split(':'))
        return h * 3600 + m * 60 + s
    except ValueError:
        raise HTTPException(status_code=400, detail="Formato de tiempo inválido. Use HH:MM:SS")

# --- Endpoint (La API) ---
@app.post("/predecir")
def predecir_rendimiento(datos: DatosJuego):
    if MODELO is None:
        raise HTTPException(status_code=500, detail="El modelo no está cargado.")

    # 1. Convertir los datos recibidos (Pydantic model) a Diccionario
    datos_dict = datos.dict()

    # 2. Crear DataFrame
    input_df = pd.DataFrame([datos_dict])

    # 3. Conversión de tiempo (Tu lógica original)
    if 'tiempo_nivel' in input_df.columns:
        input_df['tiempo_seconds'] = input_df['tiempo_nivel'].apply(tiempo_a_segundos)
        # Opcional: Eliminar la columna original si el modelo no la usa, 
        # o si causa conflicto con tipos string/object
        # input_df = input_df.drop(columns=['tiempo_nivel']) 

    try:
        # 4. Predecir
        prediccion_clase = MODELO.predict(input_df)[0]
        probabilidades = MODELO.predict_proba(input_df)[0]

        # 5. Formatear resultado
        clases = MODELO.classes_
        resultado_probs = {str(clase): round(prob * 100, 2) for clase, prob in zip(clases, probabilidades)}

        return {
            "prediccion": str(prediccion_clase),
            "probabilidades": resultado_probs
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en la predicción: {str(e)}")

if __name__ == "__main__":
    # Ejecuta el servidor en localhost, puerto 8000
    uvicorn.run(app, host="127.0.0.1", port=8000)