extends Node3D


func _on_concesionario_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Concesionario.tscn")
