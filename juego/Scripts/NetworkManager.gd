extends Node

# URL de tu servidor FastAPI (Localhost)
var ws_url = "ws://127.0.0.1:8000/ws/godot"
var socket = WebSocketPeer.new()

signal etiqueta_detectada(uid)

func _ready():
	connect_to_server()

func connect_to_server():
	print("Conectando a FastAPI...")
	var err = socket.connect_to_url(ws_url)
	if err != OK:
		print("Error al conectar.")
		set_process(false)
	else:
		print("Conexión realizada!")

func _process(delta):
	socket.poll() # Importante: procesar eventos de red
	
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		# Si hay paquetes pendientes, leerlos
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var mensaje = packet.get_string_from_utf8()
			_procesar_mensaje(mensaje)
			
	elif state == WebSocketPeer.STATE_CLOSED:
		# Opcional: Reintentar conexión aquí
		pass

func _procesar_mensaje(json_str):
	var json = JSON.new()
	var error = json.parse(json_str)
	
	if error == OK:
		var data = json.data
		# Verificamos si es una acción RFID
		if data.has("action") and data["action"] == "rfid":
			var uid = data["uid"]
			print("¡Etiqueta recibida desde Python!: ", uid)
			emit_signal("etiqueta_detectada", uid)
