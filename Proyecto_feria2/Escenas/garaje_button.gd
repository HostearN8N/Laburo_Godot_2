extends Control


func _on_garaje_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Menu_interior_garage.tscn")
