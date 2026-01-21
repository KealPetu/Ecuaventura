extends NivelBase

var intentos_maximos: int = 10

func _ready():
	modo_juego = 1 # ID para Clasico
	super._ready()

# Sobreescribimos la función virtual del padre
func verificar_condiciones_fin(ultimo_fue_acierto):
	if intentos_totales_partida >= intentos_maximos:
		terminar_juego()
	else:
		spawn_basura()
