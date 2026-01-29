class_name NivelBase
extends Node2D

var predict_url = "http://localhost:8000/predecir"
var websocket_url = "ws://127.0.0.1:8080"

# --- WEBSOCKET VARS ---
var socket = WebSocketPeer.new()
var ultimo_uid_procesado = "" 

# Nodos (Comunes a todos)
@onready var http_request = $HTTPRequest

@onready var label_info = $UI/TiempoOIntentos
@onready var label_puntaje = $UI/Puntaje
@onready var boton_volver: Button = $UI/BotonVolver

@onready var timer_nivel = $Timer

@onready var popup_resultados = $CapaUI/PopupResultados

@onready var sprite_basura = $ContenedorBasuraActual/SpriteBasura
@onready var label_nombre_residuo = $ContenedorBasuraActual/LabelNombreResiduo

@onready var contenedor_tachos = $ContenedorTachos


# Datos
var base_datos_residuos: Dictionary = {}
var lista_ordenada_juego: Array = [] 
var basura_actual: Dictionary = {}
var basura_actual_key: String = ""

# Estado del juego
var aciertos: int = 0
var intentos_totales: int = 0
var puntaje: int = 0
var juego_terminado: bool = false
var tiempo_inicio: int = 0
var velocidad_spawn_actual: float = 1.0
var input_bloqueado: bool = false
var ids_ya_procesados: Dictionary = {}

func _ready():
	cargar_datos_json()
	
	# Iniciar conexión WebSocket
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Error al conectar WebSocket: ", err)
	
	http_request.request_completed.connect(_on_request_completed)
	
	# Configuración específica del hijo (Template Method Pattern)
	_configurar_nivel_especifico() 
	
	# Iniciar juego
	tiempo_inicio = Time.get_unix_time_from_system()
	siguiente_basura()
	
	if boton_volver:
		boton_volver.pressed.connect(_on_btn_volver_menu_pressed)

func _on_btn_volver_menu_pressed():
	print("Abortando partida. Volviendo al menú...")
	
	# 1. Detener procesos críticos (opcional, pero recomendado)
	juego_terminado = true
	timer_nivel.stop()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close() # Cerramos conexión limpia
		
	# 2. Limpiar configuración temporal del servidor en GameManager
	# Esto evita que si entras a una partida nueva, se use la dificultad de esta partida abortada
	GameManager.resetear_configuracion_temporal()
	
	# 3. Cambiar escena
	get_tree().change_scene_to_file("res://Scenes/MenuPrincipal.tscn")

# --- FUNCIONES VIRTUALES (PARA SOBRESCRIBIR) ---
func _configurar_nivel_especifico():
	# Lógica por defecto: carga todo el JSON mezclado
	lista_ordenada_juego = base_datos_residuos.keys()
	lista_ordenada_juego.shuffle()

func _procesar_fin_juego_especifico():
	pass

func _actualizar_ui_feedback(exito: bool):
	pass

func _obtener_nombre_modo_backend() -> String:
	return "generico"

# --- LÓGICA COMÚN ---
func cargar_datos_json():
	var file = FileAccess.open("res://Data/datos_residuos.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			base_datos_residuos = json.data

func siguiente_basura():
	if lista_ordenada_juego.is_empty():
		finalizar_juego()
		return

	input_bloqueado = false
		
	basura_actual_key = lista_ordenada_juego.pop_front()
	basura_actual = base_datos_residuos[basura_actual_key]
	
	var textura = load(basura_actual["textura"])
	if textura:
		sprite_basura.texture = textura
	
	# --- NUEVO: Actualizar nombre y reiniciar visibilidad ---
	# Usamos .get() por si acaso el JSON no tenga el campo "nombre" en algún objeto
	label_nombre_residuo.text = str(basura_actual.get("nombre", "Residuo"))
	label_nombre_residuo.modulate.a = 1.0 # Asegurar que sea visible
	# --------------------------------------------------------

	sprite_basura.position = Vector2.ZERO 
	sprite_basura.modulate.a = 1.0
	sprite_basura.scale = Vector2(2.5, 2.5)
	sprite_basura.rotation = 0 # Asegurar rotación 0

func _process(_delta):
	if juego_terminado: return
	
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		
		# --- NUEVO: GESTIÓN DE PAUSA EN WEBSOCKET ---
		if input_bloqueado:
			# Si estamos bloqueados, LEEMOS pero DESCARTAMOS los paquetes 
			# para que no se acumulen en la cola (Buffer) y causen lag después.
			while socket.get_available_packet_count() > 0:
				socket.get_packet() # Leer al vacío
		else:
			# Si NO estamos bloqueados, procesamos normalmente
			while socket.get_available_packet_count() > 0:
				procesar_mensaje_websocket(socket.get_packet())

func procesar_mensaje_websocket(paquete_bytes):
	var mensaje_str = paquete_bytes.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(mensaje_str) == OK:
		var datos = json.data
		if datos.has("uid") and datos["uid"] != ultimo_uid_procesado:
			ultimo_uid_procesado = datos["uid"]
			if datos.has("id_residuo") and datos.has("tacho_seleccionado"):
				procesar_jugada(datos["id_residuo"], datos["tacho_seleccionado"], true)

# Unificamos input de teclado y websocket
func procesar_jugada(id_recibido: String, tacho_recibido: String, es_websocket: bool = false):

	# 1. Verificamos que no sea una cadena vacía (el teclado envía "", eso sí lo permitimos)
	# 2. Verificamos si el ID ya está en nuestro historial
	if id_recibido != "" and ids_ya_procesados.has(id_recibido):
		print("Ignorando residuo repetido: ", id_recibido)
		return # Salimos sin hacer nada (no cuenta como intento, no bloquea nada)
	
	# 3. Si es un ID nuevo y válido (no vacío), lo registramos para que no se use de nuevo
	if id_recibido != "":
		ids_ya_procesados[id_recibido] = true
	
	if input_bloqueado:
		return # Ignoramos cualquier intento si estamos en pausa
	
	input_bloqueado = true # BLOQUEAMOS INMEDIATAMENTE

	intentos_totales += 1
	
	var id_correcto = true
	# Si es por WebSocket validamos que el ID sea el de la basura actual
	if es_websocket:
		id_correcto = (id_recibido == basura_actual_key)
	
	# Validamos si el tacho elegido coincide con el tipo de basura
	var tacho_correcto = (tacho_recibido.to_lower() == basura_actual["tipo"].to_lower())
	
	# El éxito total requiere ambas cosas correctas
	var es_exito_total = id_correcto and tacho_correcto
	
	var puntos_a_sumar = _calcular_puntaje_turno(es_exito_total)
	
	if es_exito_total:
		aciertos += 1
		puntaje += puntos_a_sumar
		label_puntaje.text = "Puntaje: %d" % puntaje
	
	# 1. Feedback UI (Caras / Tiempo)
	_actualizar_ui_feedback(es_exito_total) 
	
	# 2. Nueva Animación Detallada
	animar_resultado_detallado(id_correcto, tacho_correcto, tacho_recibido)

# Nueva función de animación que maneja los 3 casos
func animar_resultado_detallado(id_correcto: bool, tacho_correcto: bool, tacho_destino_str: String):
	# CASO 3: BASURA INCORRECTA / ID NO CORRESPONDE
	if not id_correcto:
		var tween = create_tween().set_parallel(true)
		
		# Girar y encoger
		tween.tween_property(sprite_basura, "rotation", 2 * PI, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(sprite_basura, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite_basura, "modulate:a", 0.0, 0.5)
		tween.tween_property(label_nombre_residuo, "modulate:a", 0.0, 0.3)
		
		# Al terminar, usamos check_condiciones_continuar que ya maneja el flujo
		tween.chain().tween_callback(check_condiciones_continuar)
		return 

	# --- SI EL ID ES CORRECTO (CASO 1 Y 2) ---
	var nodo_tacho = _obtener_nodo_tacho(tacho_destino_str)
	
	if nodo_tacho:
		var pos_destino = nodo_tacho.global_position + Vector2(0, -50) 

		# Movimiento basura
		var tween_move = create_tween()
		tween_move.tween_property(sprite_basura, "global_position", pos_destino, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_move.parallel().tween_property(sprite_basura, "scale", Vector2(0.5, 0.5), 0.4)
		tween_move.tween_property(sprite_basura, "modulate:a", 0.0, 0.1)
		tween_move.tween_property(label_nombre_residuo, "modulate:a", 0.0, 0.2)
		
		# Callback al terminar movimiento
		tween_move.tween_callback(check_condiciones_continuar)
		
		# Animación del Tacho
		if tacho_correcto:
			animar_tacho_exito(nodo_tacho)
		else:
			animar_tacho_error(nodo_tacho)
	else:
		# Fallback por si el tacho no existe (seguridad)
		check_condiciones_continuar()

func animar_tacho_exito(tacho: Node2D):
	if not tacho: return
	var tween = create_tween()
	# Salto y Verde
	tween.tween_property(tacho, "offset:y", -30.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tacho, "modulate", Color.GREEN, 0.15)
	
	tween.chain().tween_property(tacho, "offset:y", 0.0, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tacho, "modulate", Color.WHITE, 0.3)

func animar_tacho_error(tacho: Node2D):
	if not tacho: return
	var tween = create_tween()
	# Rojo y vuelta
	tween.tween_property(tacho, "modulate", Color.RED, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.5)
	tween.tween_property(tacho, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _obtener_nodo_tacho(nombre_tacho: String) -> Node2D:
	match nombre_tacho.to_lower():
		"papel": return contenedor_tachos.get_child(0)
		"plastico": return contenedor_tachos.get_child(1)
		"organico": return contenedor_tachos.get_child(2)
	return null

func check_condiciones_continuar():

	await get_tree().create_timer(1.0).timeout # Pausa de 1.5 segundos
	_procesar_fin_juego_especifico()
	if not juego_terminado:
		siguiente_basura()

func _unhandled_input(event):
	if juego_terminado: return
	if input_bloqueado: return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A: procesar_jugada("", "papel")
			KEY_S: procesar_jugada("", "plastico")
			KEY_D: procesar_jugada("", "organico")

# --- FINALIZACIÓN ---
func finalizar_juego():
	if juego_terminado: return
	juego_terminado = true
	timer_nivel.stop()
	
	var precision = 0.0
	if intentos_totales > 0:
		precision = float(aciertos) / float(intentos_totales)
	
	popup_resultados.mostrar_datos(puntaje, precision, aciertos, intentos_totales)
	enviar_datos_backend(precision)

func enviar_datos_backend(precision: float):
	var duracion = Time.get_unix_time_from_system() - tiempo_inicio
	var time_str = "%02d:%02d:%02d" % [0, duracion / 60, int(duracion) % 60]
	
	var payload = {
		"total_aciertos": aciertos,
		"total_intentos": intentos_totales,
		"precision_jugador": precision,       # ANTES: "presicion_jugador"
		"puntaje_jugador": puntaje,
		"tiempo_nivel": time_str,
		"tipo_nivel": _obtener_nombre_modo_backend(),
		"completo_tutorial": str(_obtener_nombre_modo_backend() == "tutorial" and aciertos > 0) # ANTES: "completo_totorial"
	}
	
	var body = JSON.stringify(payload)
	http_request.request(predict_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var respuesta = json.data
			if respuesta.has("jugador") and respuesta.has("configuracion_nivel_siguiente"):
				var perfil = respuesta["jugador"]["perfil_predicho"]
				GameManager.actualizar_datos_servidor(perfil, respuesta["configuracion_nivel_siguiente"])
				popup_resultados.actualizar_texto_dificultad(perfil)
	else:
		print("ERROR SERVIDOR: Código ", response_code)
		print("Cuerpo del error: ", body.get_string_from_utf8())
		popup_resultados.actualizar_texto_dificultad("Error Conexión")

func _calcular_puntaje_turno(exito: bool) -> int:
	if exito: return 100
	return 0
