extends Control

@onready var lista_ui = $VBoxContainer/ListaPuntajes
@onready var boton_regresar: Button = $BotonRegresar

func _ready():
	mostrar_puntajes()
	boton_regresar.pressed.connect(_on_boton_regresar_pressed)

func mostrar_puntajes():
	lista_ui.clear()
	
	# Recorremos los datos guardados en el GameManager
	for entrada in GameManager.datos_leaderboard:
		var texto = "%s - %s pts (%s)" % [entrada["nombre"], str(entrada["puntaje"]), entrada["modo"]]
		lista_ui.add_item(texto)

func _on_boton_regresar_pressed():
	get_tree().change_scene_to_file("res://Scenes/MenuPrincipal.tscn")
