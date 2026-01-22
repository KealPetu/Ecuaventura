# GameManager.gd
extends Node

# Variables de configuración global
var dificultad_actual: String = "medio" # puede ser "bajo", "medio", "alto"
var ultimo_resultado_ml: Dictionary = {}

# --- NUEVAS VARIABLES LEADERBOARD ---
var nombre_jugador: String = "Jugador" # Valor por defecto
var ruta_leaderboard: String = "user://leaderboard.json"
var datos_leaderboard: Array = []

func _ready() -> void:
	cargar_leaderboard()

# Función para cargar datos al iniciar el juego
func cargar_leaderboard():
	if FileAccess.file_exists(ruta_leaderboard):
		var file = FileAccess.open(ruta_leaderboard, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			datos_leaderboard = json.data
		else:
			print("Error al leer leaderboard, creando nuevo array.")
			datos_leaderboard = []
	else:
		datos_leaderboard = []
		
# Función para guardar un nuevo puntaje
func registrar_puntaje(puntaje: int, modo: String):
	var nueva_entrada = {
		"nombre": nombre_jugador,
		"puntaje": puntaje,
		"modo": modo,
		"fecha": Time.get_datetime_string_from_system()
	}
	
	datos_leaderboard.append(nueva_entrada)
	
	# Ordenar de Mayor a Menor puntaje
	datos_leaderboard.sort_custom(func(a, b): return a["puntaje"] > b["puntaje"])
	
	# Opcional: Mantener solo los top 10 para no llenar el archivo
	if datos_leaderboard.size() > 10:
		datos_leaderboard.resize(10)
	
	guardar_en_disco()

func guardar_en_disco():
	var file = FileAccess.open(ruta_leaderboard, FileAccess.WRITE)
	var json_string = JSON.stringify(datos_leaderboard, "\t")
	file.store_string(json_string)
	file.close()

# Configuraciones de dificultad
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
