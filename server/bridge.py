import serial
import requests
import time

# Configura tu puerto (Ej: 'COM3' en Windows o '/dev/ttyUSB0' en Linux/Mac)
arduino_port = '/dev/ttyUSB0'
baud_rate = 9600
webhook_url = "localhost:8000/webhook_debug"

ser = serial.Serial(arduino_port, baud_rate, timeout=1)
time.sleep(2)  # Esperar a que reinicie el Arduino

print(f"Escuchando en {arduino_port}...")

while True:
    if ser.in_waiting > 0:
        try:
            # Leer linea del Arduino
            line = ser.readline().decode('utf-8').strip()

            if line.startswith("Card UID:"):
                print(f"Tarjeta detectada: {line}")
                payload = {'uid': line}
                requests.post(webhook_url, json=payload)

        except Exception as e:
            print(f"Error: {e}")