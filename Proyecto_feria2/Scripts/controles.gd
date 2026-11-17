extends Control

# Escena del menú al que se vuelve. Elegila desde el Inspector.
# Si la dejás vacía, la escena se cierra (sirve si la abrís encima del menú).
@export_file("*.tscn") var escena_menu: String = ""

@onready var boton_volver: Button = %Volver


func _ready() -> void:
	boton_volver.pressed.connect(_volver)
	boton_volver.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # ESC
		_volver()


func _volver() -> void:
	if escena_menu != "":
		get_tree().change_scene_to_file(escena_menu)
	else:
		queue_free()
