extends Sprite2D


func _on_reiniciar_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/autodromo_imola.tscn")
