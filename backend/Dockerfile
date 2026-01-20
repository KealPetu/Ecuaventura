# Usamos Python 3.10-slim para tener un entorno ligero y estable
FROM python:3.10-slim

# Establecemos el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiamos primero los requerimientos para aprovechar la caché de Docker
COPY requirements.txt .

# Instalamos las librerías
RUN pip install --no-cache-dir -r requirements.txt

# Copiamos el resto de los archivos (tu script server.py y el modelo .pkl)
COPY . .

# Exponemos el puerto 8000
EXPOSE 8000

# Comando para iniciar el servidor
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]