extends Control

@onready var boton_regresar: Button = $ContenedorGeneral/PanelSuperior/BotonRegresar
@onready var boton_modo_clasico: Button = $ContenedorGeneral/PanelInferior/BotonModoClasico
@onready var boton_modo_contrarreloj: Button = $ContenedorGeneral/PanelInferior/BotonModoContrarreloj
@onready var boton_como_jugar: Button = $ContenedorGeneral/PanelSuperior/BotonComoJugar

const ESCENA_LOGIN = "res://Scenes/Login.tscn"

# Rutas a tus nuevas escenas heredadas
const ESCENA_CLASICO = "res://Scenes/Modos/NivelClasico.tscn"
const ESCENA_CONTRARRELOJ = "res://Scenes/Modos/NivelContrarreloj.tscn"
const ESCENA_TUTORIAL = "res://Scenes/Modos/NivelTutorial.tscn"

func _ready() -> void:
	boton_regresar.pressed.connect(ir_escena.bind(ESCENA_LOGIN))
	
	# Conectamos directamente a la función de iniciar con la ruta correcta
	boton_modo_clasico.pressed.connect(iniciar_juego.bind(ESCENA_CLASICO))
	boton_modo_contrarreloj.pressed.connect(iniciar_juego.bind(ESCENA_CONTRARRELOJ))
	boton_como_jugar.pressed.connect(iniciar_juego.bind(ESCENA_TUTORIAL))

func ir_escena(direccion_escena: String) -> void:
	get_tree().change_scene_to_file(direccion_escena)

func iniciar_juego(ruta_escena: String):
	# Importante: Limpiamos config vieja del servidor para empezar "fresco"
	GameManager.resetear_configuracion_temporal()
	
	# Cambiamos a la escena específica del modo
	get_tree().change_scene_to_file(ruta_escena)
