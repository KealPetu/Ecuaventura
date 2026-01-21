class_name Residuo extends Node2D

var id: String
var tipo: String # "papel", "plastico", "organico"

# Referencia al sprite
@onready var sprite = $Sprite2D

func configurar_residuo(datos_diccionario: Dictionary, id_unico: String):
	id = id_unico
	tipo = datos_diccionario["tipo"]
	name = datos_diccionario["nombre"] # Útil para debug
	
	# Cargar la textura dinámicamente
	sprite.texture = load(datos_diccionario["textura"])
	
	# Aquí puedes añadir lógica para ajustar la escala si los sprites son de distinto tamaño
