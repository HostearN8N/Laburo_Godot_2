extends Node3D

func _ready() -> void:
	print("--- INICIANDO PISTA ---")
	print("Ruta en Global: ", Global.auto_seleccionado_path)
	
	# Buscamos "Fiat_500_Abarth10" en cualquier profundidad del árbol de la pista (recursive = true)
	var auto_por_defecto = find_child("Fiat_500_Abarth10", true, false) as Node3D
	print("Nodo encontrado en pista: ", auto_por_defecto)
	
	if auto_por_defecto == null:
		push_error("NO SE ENCONTRÓ 'Fiat_500_Abarth10' en la pista. Revisa el nombre exacto del nodo del jugador.")
		return
		
	if Global.auto_seleccionado_path == "" or Global.auto_seleccionado_path == "res://Autos/fiat_500_abarth.tscn":
		print("Se usa el Fiat 500 por defecto.")
		return

	# Guardamos posición, rotación y nodo padre del auto original
	var posicion_parrilla: Transform3D = auto_por_defecto.global_transform
	var padre: Node = auto_por_defecto.get_parent()
	
	# Cargamos e instanciamos el auto elegido (ej. mini_cooper_s.tscn)
	var escena_auto_nuevo = load(Global.auto_seleccionado_path) as PackedScene
	if escena_auto_nuevo == null:
		push_error("ERROR: No se pudo cargar la escena: " + Global.auto_seleccionado_path)
		return
		
	var auto_nuevo = escena_auto_nuevo.instantiate() as Node3D
	
	# Eliminamos el Fiat original antes de agregar el nuevo
	auto_por_defecto.name = "AutoViejo_Borrar"
	auto_por_defecto.queue_free()
	
	# Le ponemos el mismo nombre para que GestorPosiciones, Semáforo y HUD lo detecten solos
	auto_nuevo.name = "Fiat_500_Abarth10"
	padre.add_child(auto_nuevo)
	auto_nuevo.global_transform = posicion_parrilla
	print("¡ÉXITO! Auto reemplazado por: ", Global.auto_seleccionado_path)
