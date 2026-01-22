# PopupResultados.gd
extends Control

@onready var lbl_puntaje = $Panel/VBoxContainer/LblPuntaje
@onready var lbl_precision = $Panel/VBoxContainer/LblPrecision
@onready var lbl_dificultad = $Panel/VBoxContainer/LblDificultad
@onready var btn_reintentar = $Panel/VBoxContainer/Botones/BtnReintentar
@onready var btn_leaderboard= $Panel/VBoxContainer/Botones/BtnLeaderboard

func _ready():
	# Conectamos las señales de los botones
	$Panel/VBoxContainer/Botones/BtnReintentar.pressed.connect(_on_reintentar_pressed)
	$Panel/VBoxContainer/Botones/BtnMenu.pressed.connect(_on_menu_pressed)
	$Panel/VBoxContainer/Botones/BtnLeaderboard.pressed.connect(_on_leaderboard_pressed)
	
	# Ocultar al inicio por seguridad
	visible = false

func mostrar_datos(puntaje: int, precision: float, aciertos: int, intentos: int):
	lbl_puntaje.text = "Puntaje Final: %d" % puntaje
	lbl_precision.text = "Precisión: %.1f%% (%d/%d)" % [precision * 100, aciertos, intentos]
	lbl_dificultad.text = "Analizando tu rendimiento..." 
	
	visible = true

func actualizar_texto_dificultad(nueva_dificultad: String):
	lbl_dificultad.text = "Próxima Dificultad: " + nueva_dificultad.to_upper()
	
	# Efecto visual para indicar que ya se puede reintentar con nuevos datos
	var tween = create_tween()
	tween.tween_property(lbl_dificultad, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(lbl_dificultad, "scale", Vector2(1.0, 1.0), 0.2)

func _on_reintentar_pressed():
	get_tree().reload_current_scene() # Recarga la escena -> Dispara _ready() -> Carga nueva dificultad

func _on_menu_pressed():
	# Ir al menú principal
	visible = false
	get_tree().change_scene_to_file("res://Scenes/MenuPrincipal.tscn")

func _on_leaderboard_pressed():
	# Ir al leaderboard
	visible = false
	get_tree().change_scene_to_file("res://Scenes/Leaderboard.tscn")
