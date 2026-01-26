import serial
import requests
import time
import sys

# ==========================================
# CONFIGURACIÓN
# ==========================================
arduino_port = '/dev/ttyUSB0'  # Revisa que siga siendo el COM5
baud_rate = 9600
webhook_url = "http://localhost:3000/sensor-data"

# ==========================================
# INICIO
# ========================================== 
print("--- INICIANDO SCRIPT MULTI-LECTOR ---")

try:
    print(f"[1/4] Intentando abrir puerto {arduino_port}...")
    ser = serial.Serial(arduino_port, baud_rate, timeout=1)
    print(f"✅ Puerto {arduino_port} abierto correctamente.")
except Exception as e:
    print(f"❌ ERROR CRÍTICO abriendo puerto serial: {e}")
    sys.exit()

print("[2/4] Esperando 2 segundos a que Arduino reinicie...")
time.sleep(2)
print("✅ Espera terminada. Escuchando sistema de 3 lectores...")
print(f"[3/4] Enviando datos a: {webhook_url}")

# ==========================================
# BUCLE PRINCIPAL
# ==========================================
while True:
    try:
        if ser.in_waiting > 0:
            # Leer y limpiar
            raw = ser.readline().decode('utf-8', errors='ignore').strip()

            # ---------------------------------------------------------
            # NUEVA LÓGICA DE PARSEO (SEPARAR LECTOR Y UID)
            # ---------------------------------------------------------
            # Buscamos si el mensaje tiene el formato "LectorX:UID"
            if ":" in raw:
                try:
                    # Separamos el string en dos partes usando el ':' como guillotina
                    partes = raw.split(":")

                    nombre_lector = partes[0]  # Ej: "Lector1"
                    uid_crudo = partes[1].strip()  # Ej: "04C15B..."

                    print(f"\n[DETECTADO] {nombre_lector} -> Tarjeta: {uid_crudo}")

                    # PASO 1: Formatear el UID (Espacios cada 2 caracteres)
                    # Solo formateamos la parte del código, no el nombre del lector
                    uid_formateado = ' '.join(uid_crudo[i:i + 2] for i in range(0, len(uid_crudo), 2))

                    # PASO 2: Crear el Payload actualizado
                    # Ahora enviamos DOS datos: quién leyó y qué leyó
                    payload = {
                        'uid': uid_formateado,
                        'sensor': nombre_lector  # Enviamos "Lector1", "Lector2", etc.
                    }

                    # PASO 3: Enviar a Godot
                    print(f"   [Enviando] -> {payload}")
                    response = requests.post(webhook_url, json=payload, timeout=0.5)

                    if response.status_code == 200:
                        print("   ✅ ¡ENVIADO A GODOT CORRECTAMENTE!")
                    else:
                        print(f"   ⚠️ Godot recibió pero respondió: {response.status_code}")

                except IndexError:
                    print(f"   ⚠️ Error de formato en línea: {raw}")

            # Si el mensaje no tiene ":", es un mensaje de sistema (ej. "Sistema Listo")
            elif raw:
                print(f"[ARDUINO LOG]: {raw}")

    except requests.exceptions.ConnectionError:
        print("   ❌ ERROR: No se pudo conectar a Godot. ¿Está el juego corriendo?")
    except KeyboardInterrupt:
        print("\n--- Deteniendo Script ---")
        break
    except Exception as e:
        print(f"   ❌ Error inesperado: {e}")