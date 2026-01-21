extends NivelBase

func _ready():
	modo_juego = 2 # ID para Contrarreloj
	$TiempoPartida.start() # Configurado e.g. a 60 segundos
	super._ready()

# En este modo, el juego no termina por intentos, sino por el Timer
func _on_TiempoPartida_timeout():
	terminar_juego()

func verificar_condiciones_fin(ultimo_fue_acierto):
	# En contrareloj, siempre sigue saliendo basura hasta que el tiempo acabe
	spawn_basura()
