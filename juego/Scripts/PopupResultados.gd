# PopupResultados.gd
extends Control

@onready var fondo_oscuro = $FondoOscuro
@onready var cartel_ui = $CartelUI
@onready var lbl_puntaje = $CartelUI/VBoxContainer/LblPuntaje
@onready var lbl_precision = $CartelUI/VBoxContainer/LblPrecision
@onready var lbl_dificultad = $CartelUI/VBoxContainer/LblDificultad
@onready var btn_reintentar = $CartelUI/VBoxContainer/Botones/BtnReintentar
@onready var btn_leaderboard= $CartelUI/VBoxContainer/Botones/BtnLeaderboard

func _ready():
	# Conectamos las señales de los botones
	$CartelUI/VBoxContainer/Botones/BtnReintentar.pressed.connect(_on_reintentar_pressed)
	$CartelUI/VBoxContainer/Botones/BtnMenu.pressed.connect(_on_menu_pressed)
	$CartelUI/VBoxContainer/Botones/BtnLeaderboard.pressed.connect(_on_leaderboard_pressed)
	# Aseguramos que al inicio esté todo oculto y el cartel fuera de pantalla
	visible = false
	fondo_oscuro.modulate.a = 0.0
	
	# Mover el cartel arriba, fuera de la vista
	call_deferred("resetear_posicion_cartel")
	
	# Ocultar al inicio por seguridad
	visible = false

func mostrar_datos(puntaje: int, precision: float, aciertos: int, intentos: int):
	lbl_puntaje.text = "Puntaje Final: %d" % puntaje
	lbl_precision.text = "Precisión: %.1f%% (%d/%d)" % [precision * 100, aciertos, intentos]
	lbl_dificultad.text = "Analizando tu rendimiento..." 
	
	visible = true
	
	animar_entrada()

func actualizar_texto_dificultad(nueva_dificultad: String):
	lbl_dificultad.text = "Próxima Dificultad: " + nueva_dificultad.to_upper()
	
	# Efecto visual para indicar que ya se puede reintentar con nuevos datos
	var tween = create_tween()
	tween.tween_property(lbl_dificultad, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(lbl_dificultad, "scale", Vector2(1.0, 1.0), 0.2)

func resetear_posicion_cartel():
	# Coloca el cartel justo arriba de la pantalla
	if cartel_ui:
		cartel_ui.position.y = -cartel_ui.size.y - 100

func animar_entrada():
	# Preparamos posiciones
	resetear_posicion_cartel() # Asegurar que empieza arriba
	fondo_oscuro.modulate.a = 0.0 # Asegurar fondo transparente
	
	# Calcular el centro exacto de la pantalla
	var pantalla_size = get_viewport().get_visible_rect().size
	var destino_y = (pantalla_size.y - cartel_ui.size.y) / 2
	var destino_x = (pantalla_size.x - cartel_ui.size.x) / 2
	cartel_ui.position.x = destino_x # Centrar horizontalmente

	# Crear el Tween
	var tween = create_tween().set_parallel(true) # Animaciones simultáneas

	# 1. Aparecer el fondo oscuro suavemente (Fade in)
	tween.tween_property(fondo_oscuro, "modulate:a", 1.0, 0.4)

	# 2. Caída con rebote del cartel
	# Usamos TRANS_BOUNCE para el rebote y EASE_OUT para que ocurra al final
	# Duración: 1.0 a 1.5 segundos suele verse bien para un rebote
	tween.tween_property(cartel_ui, "position:y", destino_y, 1.2)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)

func _on_reintentar_pressed():
	get_tree().reload_current_scene() # Recarga la escena -> Dispara _ready() -> Carga nueva dificultad

func _on_menu_pressed():
	GameManager.resetear_configuracion_temporal()
	ir_a_escena("res://Scenes/MenuPrincipal.tscn")

func _on_leaderboard_pressed():
	ir_a_escena("res://Scenes/Leaderboard.tscn")

func ir_a_escena(ruta: String):
	visible = false
	# 1. Cambiamos de escena
	get_tree().change_scene_to_file(ruta)
	
	# 2. IMPORTANTE: Buscamos al nivel (el nodo abuelo o root de esta escena) y lo borramos manualmente
	# Como PopupResultados está en CapaUI -> NivelReciclaje, el owner suele ser el nivel.
	if owner:
		owner.queue_free()
