extends Control


func _on_garaje_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Menu_interior_garage.tscn")
func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
