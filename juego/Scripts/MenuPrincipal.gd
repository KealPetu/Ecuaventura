extends Control

@onready var boton_regresar: Button = $ContenedorGeneral/PanelSuperior/BotonRegresar

func _ready() -> void:
	boton_regresar.pressed.connect(regresar_menu_login)

func regresar_menu_login() -> void:
	get_tree().change_scene_to_file("res://Scenes/Login.tscn")
