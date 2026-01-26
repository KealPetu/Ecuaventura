extends NivelBase

@onready var barra_tiempo = $UI/BarraTiempo
@onready var contenedor_caras = $UI/ContenedorCaras

var tiempo_limite: int = 60
var racha_actual: int = 0
var multiplicador: int = 1

func _ready():
	contenedor_caras.visible = false
	barra_tiempo.visible = true
	label_info.text = "Racha: 0"
	
	# Conectamos señal de tiempo agotado
	timer_nivel.timeout.connect(finalizar_juego)
	
	super._ready()

func _configurar_nivel_especifico():
	# --- LÓGICA CONTRARRELOJ MODIFICADA ---
	
	# 1. Configurar TIEMPO basado en la Dificultad del GameManager
	# Ignoramos los parámetros específicos que mandó el ML, solo nos importa el perfil ("bajo", "medio", "alto")
	var perfil_dificultad = GameManager.dificultad_actual
	
	# Validación de seguridad: Si el perfil no existe en config_base, usamos "medio"
	if not GameManager.config_base.has(perfil_dificultad):
		perfil_dificultad = "medio"
	
	# Extraemos el tiempo definido en tu diccionario config_base del GameManager
	tiempo_limite = GameManager.config_base[perfil_dificultad]["tiempo_limite"]
	
	print("Contrarreloj Configurado. Perfil: %s | Tiempo: %d seg" % [perfil_dificultad, tiempo_limite])

	# 2. Configurar RESIDUOS (Ignoramos lista del ML, usamos TODOS los locales)
	lista_ordenada_juego = base_datos_residuos.keys()
	lista_ordenada_juego.shuffle()
	
	# (Opcional) Si quisieras asegurar que nunca se acaben en el tiempo límite, 
	# podrías duplicar la lista, pero con 29 items suele sobrar.
	if lista_ordenada_juego.is_empty():
		print("Error: JSON de residuos vacío.")

	# 3. Iniciar Timer y Barra
	timer_nivel.wait_time = tiempo_limite
	timer_nivel.one_shot = true
	timer_nivel.start()
	
	barra_tiempo.max_value = tiempo_limite
	barra_tiempo.value = tiempo_limite

func _process(delta):
	super._process(delta) # IMPORTANTE: Llamar al padre para mantener el WebSocket funcionando
	
	if not juego_terminado:
		var tiempo_restante = timer_nivel.time_left
		barra_tiempo.value = tiempo_restante
		
		# Cambio de color
		var ratio = tiempo_restante / tiempo_limite
		if ratio > 0.5: barra_tiempo.tint_progress = Color.GREEN
		elif ratio > 0.2: barra_tiempo.tint_progress = Color.YELLOW
		else: barra_tiempo.tint_progress = Color.RED

func _procesar_fin_juego_especifico():
	# En contrarreloj, el juego no termina por intentos, solo por tiempo (Timer signal)
	# o si se acaban las basuras en la lista
	if lista_ordenada_juego.is_empty():
		# Opcional: recargar lista o finalizar
		finalizar_juego()

func finalizar_juego():
	GameManager.registrar_puntaje(puntaje, "Contrarreloj")
	super.finalizar_juego()

func _obtener_nombre_modo_backend() -> String:
	return "contra_reloj"
	
func _calcular_puntaje_turno(exito: bool) -> int:
	if exito:
		racha_actual += 1
		
		# Lógica de Multiplicador Escalable
		if racha_actual >= 10:
			multiplicador = 4 # ¡Frenesí!
		elif racha_actual >= 5:
			multiplicador = 2 # Doble puntos
		else:
			multiplicador = 1
			
		# Efecto visual simple en la etiqueta
		actualizar_info_racha()
		
		return 100 * multiplicador
	else:
		# Si falla, reiniciamos todo
		racha_actual = 0
		multiplicador = 1
		actualizar_info_racha()
		
		# Feedback visual de "Racha perdida"
		var tween = create_tween()
		label_info.modulate = Color.RED
		tween.tween_property(label_info, "modulate", Color.WHITE, 0.5)
		
		return 0

func actualizar_info_racha():
	if multiplicador > 1:
		label_info.text = "¡Racha: %d! (x%d)" % [racha_actual, multiplicador]
		label_info.modulate = Color.YELLOW # Resaltar cuando hay multiplicador
	else:
		label_info.text = "Racha: %d" % racha_actual
		label_info.modulate = Color.WHITE

func _obtener_nombre_modo() -> String:
	return "contra_reloj"
