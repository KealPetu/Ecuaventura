extends NivelBase

func _ready():
	modo_juego = 0 # ID Tutorial
	mostrar_instruccion_inicial()

func spawn_basura():
	# Sobreescribir para que salga una basura específica (ej: siempre Papel primero)
	# y pausar para que el usuario lea.
	pass 

func verificar_condiciones_fin(ultimo_fue_acierto):
	if ultimo_fue_acierto:
		mostrar_felicitacion()
		completo_tutorial = true # 
		# Guardar estado de tutorial completado
	else:
		mostrar_correccion()

func mostrar_instruccion_inicial():
	pass
	
func mostrar_felicitacion():
	pass
	
func mostrar_correccion():
	pass
