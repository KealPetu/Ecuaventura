extends Node2D

# --- CONFIGURACIÓN ---
enum Modos { CLASICO, CONTRARRELOJ, TUTORIAL }
@export var modo_juego: Modos = Modos.CLASICO

# --- WEBSOCKET VARS ---
var socket = WebSocketPeer.new()
var websocket_url = "ws://127.0.0.1:8080" # Cambia esto a la IP/Puerto de tu emisor
var ultimo_uid_procesado = "" # Para evitar procesar el mismo mensaje dos veces si se repite

# Nodos (Ajusta las rutas según tu escena)
@onready var sprite_basura = $ContenedorBasuraActual/SpriteBasura
@onready var http_request = $HTTPRequest
@onready var label_info = $UI/TiempoOIntentos
@onready var label_puntaje = $UI/Puntaje
@onready var timer_nivel = $Timer
@onready var feedback_visual = $UI/FeedbackVisual

# Datos
var base_datos_residuos: Dictionary = {}
var lista_ordenada_juego: Array = [] # Array de claves (ID) para no repetir
var basura_actual: Dictionary = {}
var basura_actual_key: String = ""

# Estado del juego
var aciertos: int = 0
var intentos_totales: int = 0
var puntaje: int = 0
var juego_terminado: bool = false
var tiempo_inicio: int = 0

# Parámetros de dificultad (se cargan desde GameManager)
var max_intentos: int = 10
var tiempo_limite: int = 60

func _ready():
	cargar_datos_json()
	configurar_partida()
	
	# --- NUEVO: INICIAR CONEXIÓN WEBSOCKET ---
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Error al conectar WebSocket: ", err)
	else:
		print("Conectando a WebSocket en: ", websocket_url)
	
	siguiente_basura()
	
	# Conectar señal del HTTP Request
	http_request.request_completed.connect(_on_request_completed)

func cargar_datos_json():
	var file = FileAccess.open("res://Data/datos_residuos.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			base_datos_residuos = json.data
		else:
			print("Error parseando JSON")
	else:
		print("No se encontró el archivo JSON")

func configurar_partida():
	# Cargar dificultad desde el Singleton
	var config = GameManager.config_dificultad[GameManager.dificultad_actual]
	
	tiempo_inicio = Time.get_unix_time_from_system()
	
	# Preparar lista aleatoria sin repeticiones
	lista_ordenada_juego = base_datos_residuos.keys()
	lista_ordenada_juego.shuffle()
	
	match modo_juego:
		Modos.CLASICO:
			max_intentos = config["intentos_clasico"]
			label_info.text = "Intentos: 0 / " + str(max_intentos)
		Modos.CONTRARRELOJ:
			tiempo_limite = config["tiempo_limite"]
			timer_nivel.wait_time = tiempo_limite
			timer_nivel.timeout.connect(finalizar_juego)
			timer_nivel.start()
		Modos.TUTORIAL:
			max_intentos = 5 # Tutorial corto
			label_info.text = "Tutorial: 0 / 5"

func siguiente_basura():
	if lista_ordenada_juego.is_empty():
		finalizar_juego()
		return
		
	# Sacamos el siguiente ID de la lista barajada
	basura_actual_key = lista_ordenada_juego.pop_front()
	basura_actual = base_datos_residuos[basura_actual_key]
	
	# Cargar textura (Asumiendo que la ruta en el JSON es correcta para Godot)
	# Nota: Si las rutas en el JSON dicen "res://Assets...", Godot las cargará bien
	var textura = load(basura_actual["textura"])
	if textura:
		sprite_basura.texture = textura
	
	# Reiniciar posición visual si se movió
	sprite_basura.position = Vector2.ZERO 
	sprite_basura.modulate.a = 1.0

func _process(_delta):
	if juego_terminado: return
	
	# --- NUEVO: LÓGICA DE ESCUCHA CONSTANTE (POLLING) ---
	socket.poll() # Mantiene la conexión viva y revisa paquetes entrantes
	var estado = socket.get_ready_state()
	
	if estado == WebSocketPeer.STATE_OPEN:
		# Mientras haya paquetes en cola, los leemos
		while socket.get_available_packet_count() > 0:
			var paquete = socket.get_packet()
			if paquete:
				procesar_mensaje_websocket(paquete)
	elif estado == WebSocketPeer.STATE_CLOSED:
		# Opcional: Lógica de reconexión aquí si se cae
		pass
	
	# Actualizar UI de tiempo si es contrarreloj
	if modo_juego == Modos.CONTRARRELOJ:
		label_info.text = "Tiempo: %.1f" % timer_nivel.time_left

func procesar_mensaje_websocket(paquete_bytes):
	var mensaje_str = paquete_bytes.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(mensaje_str)
	
	if error == OK:
		var datos = json.data
		# Estructura esperada: 
		# {"uid": "pkt_1", "id_residuo": "04 B1...", "tacho_seleccionado": "plastico"}
		
		if datos.has("uid") and datos["uid"] == ultimo_uid_procesado:
			return 
		if datos.has("uid"):
			ultimo_uid_procesado = datos["uid"]
			
		# Buscamos 'id_residuo'
		if datos.has("id_residuo") and datos.has("tacho_seleccionado"):
			print("Recibido WS: ", datos)
			validar_jugada(datos["id_residuo"], datos["tacho_seleccionado"])
	else:
		print("Error JSON WebSocket")

func validar_jugada(id_recibido: String, tacho_recibido: String):
	intentos_totales += 1
	
	# 1. Comparación de ID Exacto
	# Verificamos si el ID que envió el sensor es IDÉNTICO a la clave actual del JSON
	var identificacion_correcta = (id_recibido == basura_actual_key)
	
	# 2. Comparación de Tacho
	var tacho_correcto = (tacho_recibido.to_lower() == basura_actual["tipo"].to_lower())
	
	print("Validando ID: ", id_recibido, " vs Actual: ", basura_actual_key)
	print("Resultado: ID Correcto? ", identificacion_correcta, " | Tacho Correcto? ", tacho_correcto)
	
	if identificacion_correcta and tacho_correcto:
		aciertos += 1
		puntaje += 100
		animar_resultado(true, tacho_recibido)
	else:
		animar_resultado(false, tacho_recibido)

func animar_resultado(es_exito: bool, tacho_destino: String):
	# Determinar posición visual del tacho destino para mover la basura ahí
	var posicion_tacho = Vector2.ZERO
	
	# Busca el nodo del tacho correspondiente
	match tacho_destino.to_lower():
		"papel": posicion_tacho = $ContenedorTachos.get_child(0).position
		"plastico": posicion_tacho = $ContenedorTachos.get_child(1).position
		"organico": posicion_tacho = $ContenedorTachos.get_child(2).position
	
	# Feedback Visual
	if es_exito:
		# Mostrar Confetti / Check
		print("¡JUGADA PERFECTA!")
	else:
		# Mostrar X roja
		print("FALLO: O identificaste mal la basura o el tacho es incorrecto")

	# Animación de movimiento
	var tween = create_tween()
	tween.tween_property(sprite_basura, "global_position", posicion_tacho + Vector2(0, 300), 0.3)
	tween.tween_property(sprite_basura, "modulate:a", 0.0, 0.1)
	tween.tween_callback(chequear_condiciones_fin)

func _unhandled_input(event):
	if juego_terminado: return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A: # Izquierda (ej. Papel)
			procesar_intento("papel", $ContenedorTachos.get_child(0).position)
		elif event.keycode == KEY_S: # Centro (ej. Plastico)
			procesar_intento("plastico", $ContenedorTachos.get_child(1).position)
		elif event.keycode == KEY_D: # Derecha (ej. Organico)
			procesar_intento("organico", $ContenedorTachos.get_child(2).position)

# Lógica para verificar respuesta y animar
func procesar_intento(tipo_seleccionado: String, posicion_objetivo: Vector2):
	intentos_totales += 1
	var es_correcto = (tipo_seleccionado.to_lower() == basura_actual["tipo"].to_lower())
	
	if es_correcto:
		aciertos += 1
		puntaje += 100 # Sistema simple de puntaje
		mostrar_feedback(true)
	else:
		mostrar_feedback(false)
	
	# Animación simple hacia el tacho
	var tween = create_tween()
	# Mover el sprite hacia la posición del tacho (ajusta coordenadas según tu escena)
	# Nota: posicion_objetivo debe ser relativa al padre o global
	tween.tween_property(sprite_basura, "global_position", posicion_objetivo + Vector2(0, 300), 0.3)
	tween.tween_property(sprite_basura, "modulate:a", 0.0, 0.1) # Desvanecer
	tween.tween_callback(chequear_condiciones_fin)

func mostrar_feedback(correcto: bool):
	# Aquí implementas tu lógica de mostrar Visto/X y confeti
	if correcto:
		print("¡Correcto!")
		# Instanciar partículas de confetti aquí
	else:
		print("Incorrecto")

func chequear_condiciones_fin():
	if modo_juego == Modos.CONTRARRELOJ:
		# En contrarreloj, solo cambiamos de basura, el fin lo dicta el Timer
		siguiente_basura()
	else:
		# En Clásico y Tutorial chequeamos intentos
		label_info.text = "Intentos: %d / %d" % [intentos_totales, max_intentos]
		if intentos_totales >= max_intentos:
			finalizar_juego()
		else:
			siguiente_basura()

# --- LÓGICA DE FINALIZACIÓN Y CONEXIÓN AL BACKEND ---

func finalizar_juego():
	if juego_terminado: return
	juego_terminado = true
	timer_nivel.stop()
	print("Juego Terminado. Enviando datos...")
	
	enviar_datos_backend()

func enviar_datos_backend():
	var duracion_segundos = Time.get_unix_time_from_system() - tiempo_inicio
	# Formatear tiempo a HH:MM:SS (simplificado)
	var time_str = "%02d:%02d:%02d" % [0, duracion_segundos / 60, int(duracion_segundos) % 60]
	
	var precision = 0.0
	if intentos_totales > 0:
		precision = float(aciertos) / float(intentos_totales)
	
	var tipo_nivel_str = "clasico"
	if modo_juego == Modos.CONTRARRELOJ: tipo_nivel_str = "contra_reloj"
	if modo_juego == Modos.TUTORIAL: tipo_nivel_str = "tutorial"
	
	# Construir JSON solicitado
	# Nota: He mantenido tus erratas ("presicion", "totorial") para coincidir con tu prompt
	# pero idealmente deberías corregirlas en el backend también.
	var payload = {
		"total_aciertos": aciertos,
		"total_intentos": intentos_totales,
		"presicion_jugador": precision,
		"puntaje_jugador": puntaje,
		"tiempo_nivel": time_str,
		"tipo_nivel": tipo_nivel_str,
		"completo_totorial": str(modo_juego == Modos.TUTORIAL and aciertos > 0) # "True" o "False" string
	}
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify(payload)
	
	# Enviar POST a localhost
	var error = http_request.request("http://localhost:8000/predecir", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Error al intentar conectar con el servidor: ", error)

func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		var respuesta = json.data
		
		print("Respuesta del servidor: ", respuesta)
		
		# IMPORTANTE: Aquí actualizamos la dificultad para la PROXIMA partida
		if respuesta.has("prediccion"):
			GameManager.actualizar_dificultad(respuesta["prediccion"])
			
		# Aquí mostrarías una ventana de "Game Over" con un botón para volver al menú
	else:
		print("Error del servidor: Código ", response_code)
