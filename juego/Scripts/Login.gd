extends Control

@onready var boton_iniciar: Button = $ContenedorVertical/BotonIniciar
@onready var input_nombre: LineEdit = $ContenedorVertical/InputNombre

func _ready() -> void:
	boton_iniciar.pressed.connect(_on_boton_iniciar_pressed_ir_menu_principal)

func _on_boton_iniciar_pressed_ir_menu_principal() -> void:
	var nombre_ingresado = input_nombre.text.strip_edges()
	
	if nombre_ingresado != "":
		GameManager.nombre_jugador = nombre_ingresado
	else:
		GameManager.nombre_jugador = "Anónimo"
	
	get_tree().change_scene_to_file("res://Scenes/MenuPrincipal.tscn")
