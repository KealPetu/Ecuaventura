# GameManager.gd
extends Node

# Variables de configuración global
var dificultad_actual: String = "medio" # puede ser "bajo", "medio", "alto"
var ultimo_resultado_ml: Dictionary = {}

# Configuraciones de dificultad (Tú defines qué cambia)
# Ejemplo: tiempo límite en contrarreloj, o velocidad de caída si añades gravedad
var config_dificultad = {
	"bajo": {"tiempo_limite": 90, "intentos_clasico": 15},
	"medio": {"tiempo_limite": 60, "intentos_clasico": 10},
	"alto": {"tiempo_limite": 45, "intentos_clasico": 7}
}

func actualizar_dificultad(prediccion_modelo: String):
	print("Actualizando dificultad a: ", prediccion_modelo)
	dificultad_actual = prediccion_modelo
	# Aquí podrías guardar esto en un archivo de guardado local si quisieras persistencia al cerrar el juego
