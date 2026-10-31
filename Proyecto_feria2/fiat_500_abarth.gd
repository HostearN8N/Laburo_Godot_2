extends VehicleBody3D

@export_category("Referencias")
@export var path_3d: Path3D ## <-- ¡Recuerda arrastrar el Path3D aquí en el Inspector!

@export_category("Configuración de IA")
@export var max_steer: float = 0.5
@export var steering_smoothness: float = 5.0
@export var lookahead_distance: float = 10.0
@export var engine_power: float = 300.0
@export var max_speed_kmh: float = 60.0

func _physics_process(delta: float) -> void:
	if path_3d == null:
		print("❌ ERROR: path_3d es NULL. ¡Arrastra el Path3D al Inspector!")
		return

	var curve: Curve3D = path_3d.curve
	if curve == null:
		print("❌ ERROR: El Path3D no tiene ninguna Curve3D dibujada.")
		return

	var path_length := curve.get_baked_length()
	if path_length <= 0.0:
		return

	# 1. Encontrar el punto más cercano en la pista
	var local_car_pos := path_3d.to_local(global_position)
	var current_offset := curve.get_closest_offset(local_car_pos)

	# 2. Calcular el punto hacia adelante (Lookahead)
	var target_offset := current_offset + lookahead_distance
	if curve.closed:
		target_offset = fposmod(target_offset, path_length)
	else:
		target_offset = minf(target_offset, path_length)

	# 3. Obtener la posición global del objetivo y convertirla a local del auto
	var target_local_curve := curve.sample_baked(target_offset)
	var target_global := path_3d.to_global(target_local_curve)
	var local_target := to_local(target_global)

	# 4. Calcular la dirección (steering)
	var steering_angle := atan2(-local_target.x, -local_target.z)
	var desired_steering := clampf(steering_angle, -max_steer, max_steer)
	
	steering = move_toward(steering, desired_steering, steering_smoothness * delta)

	# 5. Control de velocidad
	var speed_kmh := linear_velocity.length() * 3.6
	brake = 0.0 

	if speed_kmh < max_speed_kmh:
		engine_force = engine_power
	else:
		engine_force = 0.0

	# 🔍 IMPRESIÓN DE DATOS EN VIVO PARA MONITOREAR LA IA
	print("Offset actual: ", snappedf(current_offset, 1), " | Ángulo de giro: ", snappedf(steering, 2))
