extends Node2D

# --- CONFIGURACIÓN ---
enum Modos { CLASICO, CONTRARRELOJ, TUTORIAL }
@export var modo_juego: Modos = Modos.CLASICO

var predict_url = "http://localhost:8000/predecir"

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
@onready var popup_resultados = $CapaUI/PopupResultados
# NODOS DE FEEDBACK
@onready var contenedor_caras = $UI/ContenedorCaras
@onready var barra_tiempo = $UI/BarraTiempo

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
var tiempo_limite: int = 30
# Asegúrate de tener esta variable declarada si usas la velocidad de spawn para animaciones
var velocidad_spawn_actual: float = 1.0

func _ready():
	cargar_datos_json()
	configurar_partida()
	
	# --- INICIAR CONEXIÓN WEBSOCKET ---
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
	tiempo_inicio = Time.get_unix_time_from_system()
	
	# Reiniciamos la lista de juego
	lista_ordenada_juego = []
	
	# 1. VERIFICAR SI HAY CONFIGURACIÓN DEL SERVIDOR
	if not GameManager.config_proximo_nivel.is_empty():
		print("Aplicando configuración del servidor...")
		var params = GameManager.config_proximo_nivel["parametros"]
		var assets_servidor = GameManager.config_proximo_nivel["assets_residuos"]
		
		# A. Aplicar Parámetros numéricos
		if modo_juego == Modos.CONTRARRELOJ:
			tiempo_limite = int(params["tiempo_limite_segundos"])
			timer_nivel.wait_time = tiempo_limite
			timer_nivel.start()
			barra_tiempo.max_value = tiempo_limite
			barra_tiempo.value = tiempo_limite
		
		# (Opcional) Usar velocidad_spawn para acelerar animaciones si lo deseas
		if params.has("velocidad_spawn"):
			velocidad_spawn_actual = params["velocidad_spawn"]
			
		# B. Cargar SOLO los residuos que mandó el servidor
		# El servidor manda una lista de objetos: [{"id": "...", "nombre": "..."}, ...]
		for item in assets_servidor:
			var id_residuo = item["id"]
			# Verificamos que tengamos la textura y datos de ese ID en nuestro JSON local
			if base_datos_residuos.has(id_residuo):
				lista_ordenada_juego.append(id_residuo)
			else:
				print("Advertencia: El servidor pidió ID ", id_residuo, " pero no está en datos_residuos.json")
		
		# Si por alguna razón la lista quedó vacía (ids incorrectos), llenamos con fallback
		if lista_ordenada_juego.is_empty():
			lista_ordenada_juego = base_datos_residuos.keys()
			lista_ordenada_juego.shuffle()
			
	else:
		# 2. CONFIGURACIÓN DEFAULT (Si no hay datos del servidor o es primera partida)
		print("Usando configuración local por defecto.")
		var config_local = GameManager.config_base[GameManager.dificultad_actual]
		
		lista_ordenada_juego = base_datos_residuos.keys()
		lista_ordenada_juego.shuffle()
		
		if modo_juego == Modos.CONTRARRELOJ:
			tiempo_limite = config_local["tiempo_limite"]
			timer_nivel.wait_time = tiempo_limite
			timer_nivel.start()
			barra_tiempo.max_value = tiempo_limite
			barra_tiempo.value = tiempo_limite

	# Ajustes visuales de UI
	if modo_juego == Modos.CLASICO or modo_juego == Modos.TUTORIAL:
		barra_tiempo.visible = false
		contenedor_caras.visible = true
		generar_caras_iniciales()
	elif modo_juego == Modos.CONTRARRELOJ:
		contenedor_caras.visible = false
		barra_tiempo.visible = true

# ### FUNCIÓN PARA CREAR LAS CARAS ###
func generar_caras_iniciales():
	# Limpiar hijos anteriores si reiniciamos
	for hijo in contenedor_caras.get_children():
		hijo.queue_free()
	
	# Crear una etiqueta por cada vida/intento
	for i in range(max_intentos):
		var lbl = Label.new()
		lbl.text = "😐" # Cara neutral
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Aumentar tamaño de fuente para que se vean bien los emojis
		lbl.add_theme_font_size_override("font_size", 32) 
		contenedor_caras.add_child(lbl)

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
	
	# --- LÓGICA DE ESCUCHA CONSTANTE (POLLING) ---
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
		var tiempo_restante = timer_nivel.time_left
		barra_tiempo.value = tiempo_restante
		
		# Calcular porcentaje (0.0 a 1.0)
		var ratio = tiempo_restante / tiempo_limite
		
		# Cambiar color según urgencia
		if ratio > 0.5:
			barra_tiempo.tint_progress = Color.GREEN # Verde
		elif ratio > 0.2:
			barra_tiempo.tint_progress = Color.YELLOW # Amarillo
		else:
			barra_tiempo.tint_progress = Color.RED # Rojo
			# Opcional: Hacer parpadear la barra si es rojo muy bajo
			barra_tiempo.visible = int(Time.get_ticks_msec() / 100) % 2 == 0

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
	var id_correcto = (id_recibido == basura_actual_key)
	
	# 2. Comparación de Tacho
	var tacho_correcto = (tacho_recibido.to_lower() == basura_actual["tipo"].to_lower())
	
	print("Validando ID: ", id_recibido, " vs Actual: ", basura_actual_key)
	print("Resultado: ID Correcto? ", id_correcto, " | Tacho Correcto? ", tacho_correcto)
	
	var es_exito = id_correcto and tacho_correcto
	
	if es_exito:
		aciertos += 1
		puntaje += 100
		
	if modo_juego != Modos.CONTRARRELOJ:
		actualizar_cara_resultado(intentos_totales - 1, es_exito)
	
	animar_resultado(es_exito, tacho_recibido)

func actualizar_cara_resultado(indice: int, fue_exito: bool):
	# Verificamos que no nos salgamos del array (por seguridad)
	if indice < contenedor_caras.get_child_count():
		var lbl_cara = contenedor_caras.get_child(indice)
		
		if fue_exito:
			lbl_cara.text = "😁" # Cara feliz
			lbl_cara.modulate = Color.GREEN # Teñir verde
			
			# Pequeña animación de "pop"
			var tween = create_tween()
			tween.tween_property(lbl_cara, "scale", Vector2(1.5, 1.5), 0.1)
			tween.tween_property(lbl_cara, "scale", Vector2(1.0, 1.0), 0.1)
		else:
			lbl_cara.text = "😭" # Cara triste
			lbl_cara.modulate = Color.RED

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
	
	if modo_juego != Modos.CONTRARRELOJ:
		actualizar_cara_resultado(intentos_totales - 1, es_correcto)

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
	
	# Calcular estadísticas finales
	var precision = 0.0
	if intentos_totales > 0:
		precision = float(aciertos) / float(intentos_totales)
	
	# 1. Guardar en Leaderboard LOCAL
	var nombre_modo = "Clásico"
	if modo_juego == Modos.CONTRARRELOJ: nombre_modo = "Contrarreloj"
	elif modo_juego == Modos.TUTORIAL: nombre_modo = "Tutorial"
	
	# Solo guardamos si no es tutorial
	if modo_juego != Modos.TUTORIAL:
		GameManager.registrar_puntaje(puntaje, nombre_modo)
	
	# 2. MOSTRAR POPUP
	popup_resultados.mostrar_datos(puntaje, precision, aciertos, intentos_totales)
	
	# 3. Enviar a Backend (Tu lógica existente)
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
	var error = http_request.request(predict_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Error al intentar conectar con el servidor: ", error)

func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		var error = json.parse(body.get_string_from_utf8())
		
		if error == OK:
			var respuesta = json.data
			print("Respuesta completa del servidor: ", respuesta)
			
			# Navegamos la nueva estructura JSON
			if respuesta.has("jugador") and respuesta.has("configuracion_nivel_siguiente"):
				
				# 1. Extraer Perfil
				var perfil_nuevo = respuesta["jugador"]["perfil_predicho"] # "alto", "medio", "bajo"
				
				# 2. Extraer Configuración detallada
				var config_nivel = respuesta["configuracion_nivel_siguiente"]
				
				# 3. Guardar en GameManager
				GameManager.actualizar_datos_servidor(perfil_nuevo, config_nivel)
				
				# 4. Actualizar Popup
				popup_resultados.actualizar_texto_dificultad(perfil_nuevo)
				
				# (Opcional) Mostrar confianza en consola
				var confianza = respuesta["jugador"]["confianza"][perfil_nuevo]
				print("Confianza del modelo: ", confianza)
				
		else:
			print("Error al parsear JSON de respuesta")
	else:
		print("Error del servidor: Código ", response_code)
		popup_resultados.actualizar_texto_dificultad("Error Conexión")
