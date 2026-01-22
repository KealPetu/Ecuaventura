extends Control

@onready var boton_regresar: Button = $ContenedorGeneral/PanelSuperior/BotonRegresar
@onready var boton_modo_clasico: Button = $ContenedorGeneral/PanelInferior/BotonModoClasico
@onready var boton_modo_contrarreloj: Button = $ContenedorGeneral/PanelInferior/BotonModoContrarreloj
@onready var boton_como_jugar: Button = $ContenedorGeneral/PanelSuperior/BotonComoJugar

const ESCENA_LOGIN = "res://Scenes/Login.tscn"
var escena_nivel_reciclaje = preload("res://Scenes/NivelReciclaje.tscn")

func _ready() -> void:
	boton_regresar.pressed.connect(ir_escena.bind(ESCENA_LOGIN))
	boton_modo_clasico.pressed.connect(_on_boton_modo_clasico_pressed)
	boton_modo_contrarreloj.pressed.connect(_on_boton_modo_contrarreloj_pressed)
	boton_como_jugar.pressed.connect(_on_boton_como_jugar_pressed)

func ir_escena(direccion_escena: String) -> void:
	get_tree().change_scene_to_file(direccion_escena)

func _on_boton_modo_clasico_pressed():
	iniciar_juego(0)

func _on_boton_modo_contrarreloj_pressed():
	iniciar_juego(1)

func _on_boton_como_jugar_pressed():
	iniciar_juego(2)

func iniciar_juego(modo: int):
	
	var instancia_escena = escena_nivel_reciclaje.instantiate()
	instancia_escena.modo_juego = modo
	
	get_tree().root.add_child(instancia_escena)
	self.queue_free()
