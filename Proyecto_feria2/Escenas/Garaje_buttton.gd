extends ColorRect
func _on_garaje_2_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Escenas/Menu_interior_garage.tscn")
