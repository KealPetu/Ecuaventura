class_name NivelBase extends Node2D

var juego_terminado: bool =  false
var base_datos_residuos: Dictionary = {}

# --- Datos Globales y Configuración ---
# 
var modo_juego: int = 0 
var dificultad_actual: int = 1 
var completo_tutorial: bool = false 

# --- Métricas para el Modelo ---
# 
var ratio_tiempo: float = 0.0 
var tiempo_inicio_intento: float = 0.0
var tiempo_promedio_esperado: float = 2.0 # Ajustable por dificultad

# Datos por partida 
var precision_total: float = 0.0
var puntaje_total: int = 0
var intentos_totales_partida: int = 0
var aciertos_totales: int = 0

# Datos por intento 
var precision_actual: float = 0.0
var racha_actual: int = 0 # Positiva o negativa

# --- Lógica de Selección de Residuos ---
@export var escena_residuo: PackedScene # Arrastra aquí tu Residuo.tscn en el editor
var ids_disponibles: Array = [] # Esta será nuestra "bolsa" mezclada
var residuo_actual_nodo: Node = null # Referencia al objeto en pantalla
var tipo_basura_actual: String = "" # Para comparar con el tacho

func _ready():
	cargar_datos_desde_json()
	preparar_pool_residuos() # Paso 1: Llenar la lista
	iniciar_juego()
	$ContenedorBasura.position = Vector2(get_viewport_rect().end.x/2, get_viewport_rect().end.y/2)
	$ContenedorBasura.scale = Vector2(1.5, 1.5)

func cargar_datos_desde_json():
	var archivo_path = "res://Data/datos_residuos.json"
	
	if not FileAccess.file_exists(archivo_path):
		print("ERROR: No se encontró el archivo de datos")
		return

	var archivo = FileAccess.open(archivo_path, FileAccess.READ)
	var texto_json = archivo.get_as_text()
	
	var json = JSON.new()
	var error = json.parse(texto_json)
	
	if error == OK:
		base_datos_residuos = json.data
	else:
		print("ERROR al parsear JSON: ", json.get_error_message())

func preparar_pool_residuos():
	# Obtenemos todos los keys del diccionario (res_001, res_002...)
	ids_disponibles = base_datos_residuos.keys()
	# MEZCLAMOS la lista aleatoriamente una sola vez al inicio
	ids_disponibles.shuffle()

func iniciar_juego():
	spawn_basura()

func spawn_basura():
	if juego_terminado == true: return
	# Verificamos si quedan residuos
	if ids_disponibles.is_empty():
		print("¡Se acabaron los residuos únicos!")
		terminar_juego() # O finalizar nivel
		return

	# Limpiar basura anterior si existe
	if residuo_actual_nodo != null:
		residuo_actual_nodo.queue_free()

	# --- MÉTRICAS ---
	tiempo_inicio_intento = Time.get_ticks_msec() / 1000.0
	
	# --- SELECCIÓN ÚNICA ---
	# Sacamos el último ID de la lista (pop_back elimina y retorna el valor)
	# Al eliminarlo, garantizamos que NO SE REPITA en esta partida.
	var id_seleccionado = ids_disponibles.pop_back()
	var datos_residuo = base_datos_residuos[id_seleccionado]
	
	# --- INSTANCIACIÓN ---
	residuo_actual_nodo = escena_residuo.instantiate()
	# Añadimos al contenedor de basura en la escena
	$ContenedorBasura.add_child(residuo_actual_nodo)
	
	# Configuramos el objeto visualmente
	residuo_actual_nodo.configurar_residuo(datos_residuo, id_seleccionado)
	
	# Guardamos el tipo correcto para la validación lógica
	tipo_basura_actual = datos_residuo["tipo"]

# Esta función se llama cuando el jugador presiona un tacho
func procesar_intento(tipo_tacho_seleccionado, tipo_basura_real):
	var es_correcto = (tipo_tacho_seleccionado == tipo_basura_real)
	intentos_totales_partida += 1
	
	# Cálculos métricos inmediatos
	if es_correcto:
		aciertos_totales += 1
		puntaje_total += 10 * dificultad_actual
		if racha_actual < 0: racha_actual = 0
		racha_actual += 1
	else:
		if racha_actual > 0: racha_actual = 0
		racha_actual -= 1 # Racha negativa
		
	# Calcular métricas derivadas
	precision_actual = float(aciertos_totales) / float(intentos_totales_partida) # 
	precision_total = precision_actual # Al final de la partida será el total 
	
	# Calcular RatioTiempo 
	var tiempo_actual = Time.get_ticks_msec() / 1000.0
	var tiempo_tomado = tiempo_actual - tiempo_inicio_intento
	ratio_tiempo = tiempo_tomado / tiempo_promedio_esperado
	
	# Feedback visual y siguiente paso
	mostrar_feedback(es_correcto)
	verificar_condiciones_fin(es_correcto) # Función virtual a sobreescribir

func verificar_condiciones_fin(ultimo_fue_acierto):
	# Por defecto, solo respawnea basura (comportamiento base)
	spawn_basura()

func mostrar_feedback(es_correcto):
	pass # Implementar animación de acierto/fallo

func terminar_juego():
	juego_terminado = true
