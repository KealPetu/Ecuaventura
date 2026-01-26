const WebSocket = require('ws');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

// --- CONFIGURACIÓN DE PUERTOS ---
const HTTP_PORT = 3000; 
const WS_PORT = 8080;   

// --- CONFIGURACIÓN DE HARDWARE (MAPEO) ---
// Aquí defines qué "nombre de sensor" corresponde a qué "tipo de tacho" en el juego.
// Ajusta esto según cómo hayas conectado tus cables/lectores.
const MAPA_SENSORES = {
    "Lector 3": "papel",
    "Lector 2": "plastico",
    "Lector 1": "organico"
};

// 1. INICIAR SERVIDOR HTTP (EXPRESS)
const app = express();
app.use(cors()); 
app.use(bodyParser.json()); 

// 2. INICIAR SERVIDOR WEBSOCKET
const wss = new WebSocket.Server({ port: WS_PORT });
let godotClient = null;

console.log(`🟦 WebSocket esperando a Godot en ws://localhost:${WS_PORT}`);
console.log(`🟩 API HTTP esperando datos en http://localhost:${HTTP_PORT}/sensor-data`);

// Manejo de conexión WebSocket
wss.on('connection', (ws) => {
    console.log("✅ Godot se ha conectado al WebSocket");
    godotClient = ws;

    ws.on('close', () => {
        console.log("❌ Godot se desconectó");
        godotClient = null;
    });
});

// 3. ENDPOINT HTTP (Adaptado al nuevo formato)
// Espera recibir: {"uid": "04 11...", "sensor": "Lector 2"}
app.post('/sensor-data', (req, res) => {
    const datosHardware = req.body;

    // Validación: ¿Vienen los datos necesarios?
    if (!datosHardware.uid || !datosHardware.sensor) {
        return res.status(400).json({ 
            error: "Formato incorrecto. Se requiere 'uid' y 'sensor'." 
        });
    }

    // TRADUCCIÓN: Convertimos "LectorX" a "plastico/papel/organico"
    const tachoTraducido = MAPA_SENSORES[datosHardware.sensor];

    if (!tachoTraducido) {
        console.error(`⚠️ Sensor desconocido recibido: ${datosHardware.sensor}`);
        return res.status(400).json({ error: `Sensor '${datosHardware.sensor}' no configurado en el mapa.` });
    }

    // Verificar conexión con Godot
    if (!godotClient || godotClient.readyState !== WebSocket.OPEN) {
        console.log("⚠️ Dato recibido correctamente, pero Godot no está conectado.");
        return res.status(503).json({ error: "Godot no está conectado" });
    }

    // Preparar el paquete final para Godot
    // Godot espera: { id_residuo, tacho_seleccionado }
    const payloadParaGodot = {
        uid: "pkt_" + Date.now(), 
        id_residuo: datosHardware.uid,         // El hardware manda 'uid', Godot recibe 'id_residuo'
        tacho_seleccionado: tachoTraducido     // El hardware manda 'Lector 2', Godot recibe 'plastico'
    };

    // Enviar
    try {
        godotClient.send(JSON.stringify(payloadParaGodot));
        console.log(`Input: [${datosHardware.uid}, ${datosHardware.sensor}] -> Output Godot: [${tachoTraducido}]`);
        res.status(200).json({ status: "Procesado y enviado a Godot" });
    } catch (error) {
        console.error("Error al enviar:", error);
        res.status(500).json({ error: "Fallo interno al enviar WS" });
    }
});

app.listen(HTTP_PORT, () => {
    console.log(`🚀 Servidor Puente listo.`);
});