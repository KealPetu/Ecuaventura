extends Control

@onready var boton_regresar: Button = $ContenedorGeneral/PanelSuperior/BotonRegresar
@onready var boton_modo_clasico: Button = $ContenedorGeneral/PanelInferior/BotonModoClasico
@onready var boton_modo_contrareloj: Button = $ContenedorGeneral/PanelInferior/BotonModoContrareloj
@onready var boton_como_jugar: Button = $ContenedorGeneral/PanelSuperior/BotonComoJugar

func _ready() -> void:
	boton_modo_clasico.pressed.connect(ir_modo_clasico)
	boton_regresar.pressed.connect(regresar_menu_login)
	boton_modo_contrareloj.pressed.connect(ir_modo_contrarreloj)
	boton_como_jugar.pressed.connect(ir_tutorial)

func regresar_menu_login() -> void:
	get_tree().change_scene_to_file("res://Scenes/Login.tscn")
	
func ir_modo_clasico():
	get_tree().change_scene_to_file("res://Scenes/Modos/NivelClasico.tscn")

func ir_modo_contrarreloj():
	get_tree().change_scene_to_file("res://Scenes/Modos/NivelContrarreloj.tscn")
	
func ir_tutorial():
	get_tree().change_scene_to_file("res://Scenes/Modos/NivelTutorial.tscn")
