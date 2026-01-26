extends NivelBase

@onready var contenedor_caras = $UI/ContenedorCaras
@onready var barra_tiempo = $UI/BarraTiempo

var max_intentos: int = 0

func _ready():
	# Aseguramos visibilidad correcta de UI
	barra_tiempo.visible = false
	contenedor_caras.visible = true
	super._ready() # Llama al ready del padre (conecta websocket, carga json)

func _configurar_nivel_especifico():
	# 1. Cargar la lista de residuos (Lógica Servidor vs Local)
	if not GameManager.config_proximo_nivel.is_empty():
		# --- CASO: YA TENEMOS RESPUESTA DEL MODELO ---
		# Usamos la lista específica que nos mandó el servidor
		var assets = GameManager.config_proximo_nivel["assets_residuos"]
		for item in assets:
			if base_datos_residuos.has(item["id"]):
				lista_ordenada_juego.append(item["id"])
				
		# Mezclamos para que el orden sea sorpresa
		lista_ordenada_juego.shuffle()
		
		print("Configuración recibida del servidor aplicada.")
		
	else:
		# --- CASO: PRIMERA PARTIDA (O SIN CONEXIÓN) ---
		# Cargamos todos los residuos disponibles localmente
		lista_ordenada_juego = base_datos_residuos.keys()
		lista_ordenada_juego.shuffle()
		
		# --- CAMBIO APLICADO AQUÍ ---
		# Si es la configuración local por defecto, limitamos a 10 residuos
		# para que la primera partida no sea eterna (29 es demasiado).
		if lista_ordenada_juego.size() > 10:
			lista_ordenada_juego.resize(10)
		
		print("Configuración Local aplicada: 10 items aleatorios.")

	# Fallback de seguridad por si la lista quedó vacía
	if lista_ordenada_juego.is_empty():
		lista_ordenada_juego = base_datos_residuos.keys()
		lista_ordenada_juego.shuffle()
		if lista_ordenada_juego.size() > 10:
			lista_ordenada_juego.resize(10)

	# 2. Configurar intentos según la cantidad final de items
	max_intentos = lista_ordenada_juego.size()

	# 3. Generar la UI
	generar_caras_iniciales()
	actualizar_label_intentos()

func generar_caras_iniciales():
	# Limpiar hijos anteriores
	for hijo in contenedor_caras.get_children(): 
		hijo.queue_free()
	
	# La propiedad 'columns' ya debería estar en 5 desde el editor, 
	# pero por seguridad la forzamos aquí:
	if contenedor_caras is GridContainer:
		contenedor_caras.columns = 5
	
	for i in range(max_intentos):
		var lbl = Label.new()
		lbl.text = "😐"
		lbl.add_theme_font_size_override("font_size", 32)
		
		# --- MEJORA DE ALINEACIÓN ---
		# Hacemos que cada cara ocupe su espacio en la celda y se centre
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# -----------------------------
		
		contenedor_caras.add_child(lbl)

func _actualizar_ui_feedback(exito: bool):
	var indice = intentos_totales - 1
	if indice < contenedor_caras.get_child_count():
		var lbl_cara = contenedor_caras.get_child(indice)
		if exito:
			lbl_cara.text = "😁"
			lbl_cara.modulate = Color.GREEN
		else:
			lbl_cara.text = "😭"
			lbl_cara.modulate = Color.RED
	actualizar_label_intentos()

func actualizar_label_intentos():
	label_info.text = "Intentos: %d / %d" % [intentos_totales, max_intentos]

func _procesar_fin_juego_especifico():
	if intentos_totales >= max_intentos:
		finalizar_juego()

func finalizar_juego():
	GameManager.registrar_puntaje(puntaje, "Clásico")
	super.finalizar_juego()

func _obtener_nombre_modo_backend() -> String:
	return "clasico"
