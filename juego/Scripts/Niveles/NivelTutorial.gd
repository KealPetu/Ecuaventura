extends NivelBase

# Estados del Tutorial
enum Pasos { INTRO, PASO_PAPEL, PASO_PLASTICO, PASO_ORGANICO, FIN }
var paso_actual = Pasos.INTRO

# Nodo de instrucciones (Lo crearemos por código para no ensuciar la escena base)
var lbl_instrucciones: Label

# Datos específicos para el tutorial (IDs que sabemos que existen en tu JSON)
# Asegúrate de que estos IDs existan en tu datos_residuos.json o el juego crasheará.
# Si no estás seguro, usa ids genéricos o busca por tipo.
var items_tutorial = []

func _ready():
	# 1. Configurar UI de Tutorial
	crear_ui_instrucciones()
	
	# Ocultamos cosas innecesarias del modo normal
	if has_node("UI/ContenedorCaras"): $UI/ContenedorCaras.visible = false
	if has_node("UI/BarraTiempo"): $UI/BarraTiempo.visible = false
	if has_node("UI/TiempoOIntentos"): $UI/TiempoOIntentos.visible = false
	
	super._ready()

func crear_ui_instrucciones():
	lbl_instrucciones = Label.new()
	# Configuración visual
	lbl_instrucciones.add_theme_font_size_override("font_size", 48)
	lbl_instrucciones.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_instrucciones.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_instrucciones.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Posición (Arriba en el centro)
	lbl_instrucciones.custom_minimum_size = Vector2(800, 200)
	lbl_instrucciones.position = Vector2(400, 100) # Ajusta según tu resolución (ej. 1600x900)
	
	# Agregar a la UI
	$UI.add_child(lbl_instrucciones)

func _configurar_nivel_especifico():
	# En lugar de cargar todo al azar, buscamos 1 ejemplo de cada tipo
	items_tutorial = []
	items_tutorial.append(buscar_id_por_tipo("papel"))
	items_tutorial.append(buscar_id_por_tipo("plastico"))
	items_tutorial.append(buscar_id_por_tipo("organico"))
	
	# Iniciamos la secuencia
	avanzar_paso(Pasos.PASO_PAPEL)

func buscar_id_por_tipo(tipo: String) -> String:
	for key in base_datos_residuos:
		if base_datos_residuos[key]["tipo"].to_lower() == tipo:
			return key
	return "" # No debería pasar si el JSON está bien

# --- LÓGICA DE CONTROL DE PASOS ---

func avanzar_paso(nuevo_paso):
	paso_actual = nuevo_paso
	input_bloqueado = false # Asegurar que se puede jugar
	
	match paso_actual:
		Pasos.PASO_PAPEL:
			mostrar_instruccion("¡Bienvenido!\nEste es un residuo de PAPEL.\nPresiona [A] o tíralo al tacho BLANCO.")
			destacar_tacho("papel")
			cargar_basura_tutorial(0) # Primer item de la lista
			
		Pasos.PASO_PLASTICO:
			mostrar_instruccion("¡Excelente!\nAhora tenemos PLÁSTICO.\nPresiona [S] o tíralo al tacho AZUL.")
			destacar_tacho("plastico")
			cargar_basura_tutorial(1)
			
		Pasos.PASO_ORGANICO:
			mostrar_instruccion("¡Muy bien!\nPor último, esto es ORGÁNICO.\nPresiona [D] o tíralo al tacho VERDE.")
			destacar_tacho("organico")
			cargar_basura_tutorial(2)
			
		Pasos.FIN:
			lbl_instrucciones.text = ""
			finalizar_tutorial()

func cargar_basura_tutorial(indice: int):
	# Cargamos manualmente la basura sin usar la lista aleatoria de NivelBase
	if indice < items_tutorial.size():
		basura_actual_key = items_tutorial[indice]
		basura_actual = base_datos_residuos[basura_actual_key]
		
		# Actualizar Sprite y Texto (copiado de NivelBase para forzarlo aquí)
		var textura = load(basura_actual["textura"])
		if textura: sprite_basura.texture = textura
		
		label_nombre_residuo.text = str(basura_actual.get("nombre", "Tutorial"))
		label_nombre_residuo.modulate.a = 1.0
		
		sprite_basura.position = Vector2.ZERO 
		sprite_basura.modulate.a = 1.0
		sprite_basura.scale = Vector2(2.5, 2.5)
		sprite_basura.rotation = 0

# --- SOBRESCRIBIMOS EL PROCESAMIENTO DE JUGADA ---
# Esto es vital: No queremos usar la lógica normal que cuenta intentos y fallos.
func procesar_jugada(id_recibido: String, tacho_recibido: String, es_websocket: bool = false):
	if input_bloqueado: return
	
	# Validaciones simples
	var tacho_correcto = (tacho_recibido.to_lower() == basura_actual["tipo"].to_lower())
	# En tutorial asumimos que el ID es correcto si viene del teclado, o validamos si es socket
	var id_correcto = true 
	if es_websocket: id_correcto = (id_recibido == basura_actual_key)

	if id_correcto and tacho_correcto:
		# ¡ACIERTO!
		input_bloqueado = true
		mostrar_instruccion("¡Correcto!")
		
		# Animación de éxito
		animar_resultado_detallado(true, true, tacho_recibido)
		
		# Esperar y pasar al siguiente paso
		await get_tree().create_timer(1.5).timeout
		match paso_actual:
			Pasos.PASO_PAPEL: avanzar_paso(Pasos.PASO_PLASTICO)
			Pasos.PASO_PLASTICO: avanzar_paso(Pasos.PASO_ORGANICO)
			Pasos.PASO_ORGANICO: avanzar_paso(Pasos.FIN)
			
	else:
		# ¡FALLO! (En tutorial no penalizamos, solo avisamos)
		animar_error_tutorial()
		mostrar_instruccion("¡Ups! Ese no es el tacho correcto.\nIntenta de nuevo.")

# Animación suave si se equivoca (sacudida)
func animar_error_tutorial():
	var tween = create_tween()
	var pos_orig = Vector2.ZERO
	tween.tween_property(sprite_basura, "position:x", 20, 0.05)
	tween.tween_property(sprite_basura, "position:x", -20, 0.05)
	tween.tween_property(sprite_basura, "position:x", 0, 0.05)
	# No bloqueamos input mucho tiempo, dejamos intentar rápido

# --- AYUDAS VISUALES ---
func mostrar_instruccion(texto: String):
	lbl_instrucciones.text = texto
	# Pequeño efecto de pop
	lbl_instrucciones.scale = Vector2(1.2, 1.2)
	var tween = create_tween()
	tween.tween_property(lbl_instrucciones, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BOUNCE)

func destacar_tacho(tipo: String):
	# Reseteamos todos
	for tacho in contenedor_tachos.get_children():
		tacho.modulate = Color(0.5, 0.5, 0.5) # Oscurecer los que no son
	
	# Iluminamos el correcto
	var tacho_objetivo = _obtener_nodo_tacho(tipo)
	if tacho_objetivo:
		tacho_objetivo.modulate = Color(1.5, 1.5, 1.5) # Brillar
		
		# Animación de "latido" para llamar la atención
		var tween = create_tween().set_loops(3) # Lo hace 3 veces
		tween.tween_property(tacho_objetivo, "scale", Vector2(6.1, 6.1), 0.5)
		tween.tween_property(tacho_objetivo, "scale", Vector2(6.0, 6.0), 0.5)
		
		# Al terminar los loops, volver a color normal
		tween.finished.connect(func(): 
			if is_instance_valid(tacho_objetivo): 
				tacho_objetivo.modulate = Color.WHITE
				for t in contenedor_tachos.get_children(): t.modulate = Color.WHITE
		)

func finalizar_tutorial():
	# Usamos mostrar_datos solo para activar la animación, pasando valores dumm
	popup_resultados.mostrar_datos(0, 1.0, 3, 3)
	juego_terminado = true
	# Personalizamos el Popup para el mensaje final
	popup_resultados.get_node("CartelUI/VBoxContainer/Titulo").text = "¡Entrenamiento Completo!" # Asegura la ruta correcta
	popup_resultados.get_node("CartelUI/VBoxContainer/LblPuntaje").text = "¡Estás listo para la aventura!"
	popup_resultados.get_node("CartelUI/VBoxContainer/LblPrecision").text = ""
	popup_resultados.get_node("CartelUI/VBoxContainer/LblDificultad").text = ""

# Sobrescribimos para que NO haga nada en el tutorial (evitar conflictos)
func siguiente_basura():
	pass 

func _obtener_nombre_modo_backend() -> String:
	return "tutorial"
