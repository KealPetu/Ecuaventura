const WebSocket = require('ws');
const readline = require('readline');

const wss = new WebSocket.Server({ port: 8080 });

console.log("🟦 Servidor WebSocket iniciado en ws://localhost:8080");

// DATOS REALES DEL JSON (ID es la Key, Tipo para el tacho)
const datosResiduos = [
    { 
        id: "04 B1 51 4C 2A 02 89", 
        nombre: "Botella de Agua", 
        tipo: "plastico" 
    },
    { 
        id: "04 01 9E 48 2A 02 89", 
        nombre: "Cáscara de Banana", 
        tipo: "organico" 
    },
    { 
        id: "04 11 59 39 2A 02 89", 
        nombre: "Periódico Viejo", 
        tipo: "papel" 
    }
];

let godotClient = null;

wss.on('connection', function connection(ws) {
    console.log("✅ Godot conectado");
    godotClient = ws;
    ws.on('close', () => godotClient = null);
});

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

console.log("\n--- CONTROLES ---");
console.log("[ENTER] -> Enviar dato ALEATORIO (ID + Tacho Correcto)");
console.log("Escribe 'plastico', 'organico', o 'papel' -> Enviar dato específico de ese tipo.");
console.log("-----------------\n");

rl.on('line', (input) => {
    if (!godotClient) return console.log("⚠️ Esperando conexión...");

    let residuoSeleccionado;

    // Buscar por tipo si el usuario escribe algo
    if (input.trim() !== "") {
        residuoSeleccionado = datosResiduos.find(r => r.tipo.toLowerCase() === input.trim().toLowerCase());
    }
    
    // Si no encontró o no escribió nada, aleatorio
    if (!residuoSeleccionado) {
        residuoSeleccionado = datosResiduos[Math.floor(Math.random() * datosResiduos.length)];
    }

    enviarDatos(residuoSeleccionado);
});

function enviarDatos(residuo) {
    // Estructura JSON solicitada: UID Paquete + ID Residuo + Tacho
    const payload = {
        uid: "pkt_" + Date.now(), 
        id_residuo: residuo.id,        // EJ: "04 B1 51 4C 2A 02 89"
        tacho_seleccionado: residuo.tipo // EJ: "plastico"
    };

    godotClient.send(JSON.stringify(payload));
    console.log(`📤 Enviado: ${residuo.nombre} (ID: ${residuo.id}) -> Tacho: ${residuo.tipo}`);
}