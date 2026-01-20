extends Control

@onready var boton_iniciar: Button = $ContenedorVertical/BotonIniciar

func _ready() -> void:
	boton_iniciar.pressed.connect(_on_boton_iniciar_pressed_ir_menu_principal)

func _on_boton_iniciar_pressed_ir_menu_principal() -> void:
	get_tree().change_scene_to_file("res://Scenes/MenuPrincipal.tscn")
	pass 
