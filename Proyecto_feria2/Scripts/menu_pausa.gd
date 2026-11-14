extends CanvasLayer

func _ready() -> void:
	visible = false
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().paused:
			_cerrar_pausa()
		else:
			_abrir_pausa()

func _abrir_pausa() -> void:
	visible = true
	get_tree().paused = true
	# Mostramos y liberamos el cursor para que pueda hacer clic
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _cerrar_pausa() -> void:
	visible = false
	get_tree().paused = false
	# Si tu juego de carreras oculta el cursor durante la partida, vuelve a capturarlo aquí:
	# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 
	# O déjalo visible si tu juego lo requiere:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_continuar_pressed() -> void:
	_cerrar_pausa()
