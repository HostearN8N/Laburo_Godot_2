extends VehicleBody3D


# =========================================
# REFERENCIA AL CIRCUITO
# =========================================

@export var path_follow: PathFollow3D


# =========================================
# CONFIGURACION DEL MOTOR
# =========================================

@export_group("Motor")

@export var engine_power: float = 50.0
@export var brake_power: float = 28.0
@export var max_speed: float = 160.0
@export var corner_speed: float = 65.0

# La fuerza del motor aumenta de forma progresiva, pero con una rampa
# mas viva para que la salida tenga respuesta de juego de carreras.
# Los valores representan unidades de engine_force por segundo.
@export var engine_force_ramp_up: float = 200.0
@export var engine_force_ramp_down: float = 100.0

# Ajusta la potencia segun la diferencia entre la velocidad actual y la objetivo.
@export var acceleration_speed_window: float = 36.0
@export_range(0.1, 1.0, 0.05)
var max_acceleration_fraction: float = 0.90


# =========================================
# CONFIGURACION DE DIRECCION
# =========================================

@export_group("Direccion")

@export var wheelbase: float = 2.4
@export var max_steer: float = 0.45
@export var lookahead_distance: float = 14.0
@export var steering_response: float = 2.5
@export var invert_steering: bool = false


# =========================================
# TRAZADA INDIVIDUAL
# =========================================
# La transicion desde la posicion de largada hasta la linea ideal
# ahora se completa a lo largo de al menos 160 metros, para evitar que los bots
# converjan todos hacia su trazada demasiado pronto.

@export_group("Trazada individual")

@export_range(-5.0, 5.0, 0.1)
var lateral_offset: float = 0.0

@export var lateral_profile: Curve

@export_range(-5.0, 5.0, 0.1)
var start_lateral_offset: float = 0.0

@export_range(0.0, 300.0, 1.0)
var merge_distance: float = 160.0

# Captura automaticamente el carril real que ocupa cada auto en la grilla.
# Asi no convergen todos al centro cuando comienza la carrera.
@export var capture_start_grid_offset: bool = true

var merge_distance_travelled: float = 0.0


# =========================================
# EVASION DE OBSTACULOS
# =========================================

@export_group("Evasion de obstaculos")

@export var avoidance_enabled: bool = true

@export var avoidance_collision_mask: int = 4294967295

@export var forward_sensor_length: float = 32.0
@export var side_sensor_length: float = 9.0

@export var sensor_forward_offset: float = 1.5
@export var sensor_height: float = 0.65
@export var sensor_spread: float = 0.30

@export var avoidance_trigger_distance: float = 5.5
@export var avoidance_ttc_threshold: float = 1.8

@export var minimum_escape_clearance: float = 3.0

@export var avoidance_offset_distance: float = 1.1
@export var avoidance_response: float = 4.0

@export_range(-1.0, 1.0, 1.0)
var avoidance_preference: float = 1.0

@export var avoidance_hold_time: float = 0.30

@export var emergency_gap_distance: float = 2.0
@export var emergency_ttc: float = 0.45
@export var obstacle_brake_power: float = 32.0


# =========================================
# VARIABLES INTERNAS DE EVASION
# =========================================

var avoidance_offset: float = 0.0
var active_avoidance_side: float = 0.0
var avoidance_hold_timer: float = 0.0


# =========================================
# RECUPERACION A LA PISTA
# =========================================

@export_group("Recuperacion a pista")

@export var recovery_enabled: bool = true

@export var off_track_recovery_distance: float = 7.0
@export var recovery_complete_distance: float = 2.5
@export var recovery_lookahead_distance: float = 7.0
@export var recovery_speed_limit: float = 55.0
@export var recovery_collision_hold: float = 1.2
@export var recovery_stable_time: float = 0.75
@export var recovery_steering_response: float = 3.5

# La IA entra en recuperacion si queda mirando muy lejos de la direccion
# de la pista. Para finalizarla debe volver a quedar razonablemente alineada.
@export_range(-1.0, 1.0, 0.05)
var recovery_heading_threshold: float = 0.15
@export_range(-1.0, 1.0, 0.05)
var recovery_heading_complete_threshold: float = 0.75

# Maniobra lenta para reorientarse despues de un trompo o choque.
@export var recovery_maneuver_speed: float = 12.0
@export_range(0.05, 1.0, 0.05)
var recovery_maneuver_power: float = 0.35
@export var recovery_maneuver_brake: float = 18.0
@export var recovery_reverse_heading_threshold: float = 0.0

var recovery_active: bool = false
var recovery_collision_timer: float = 0.0
var recovery_stable_timer: float = 0.0
var current_engine_force: float = 0.0


# =========================================
# PROTECCION DE SALIDA
# =========================================

@export_group("Salida")

@export var launch_avoidance_delay: float = 4.5
@export var launch_avoidance_distance: float = 30.0
@export var recovery_collision_min_relative_speed: float = 4.0

var race_elapsed: float = 0.0
var distance_since_launch: float = 0.0


# =========================================
# VARIABLES GENERALES
# =========================================

var warned_target_behind: bool = false
var own_collision_rids: Array[RID] = []


# =========================================
# INICIALIZACION
# =========================================

func _ready() -> void:

	if path_follow == null:
		push_error("AI: No se asigno PathFollow3D.")

	# Activar deteccion de colisiones.

	contact_monitor = true
	max_contacts_reported = 8

	own_collision_rids.clear()
	own_collision_rids.append(get_rid())
	for child in find_children("*", "CollisionObject3D", true, false):
		if child is CollisionObject3D:
			own_collision_rids.append((child as CollisionObject3D).get_rid())

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_capture_starting_grid_offset()


func _capture_starting_grid_offset() -> void:
	if not capture_start_grid_offset:
		return
	if not is_instance_valid(path_follow):
		return

	var path: Path3D = path_follow.get_parent() as Path3D
	if path == null or path.curve == null:
		return

	var curve: Curve3D = path.curve
	var car_local: Vector3 = path.to_local(global_position)
	var closest_offset: float = curve.get_closest_offset(car_local)
	var frame: Transform3D = curve.sample_baked_with_rotation(closest_offset)
	var lateral_axis: Vector3 = frame.basis.x.normalized()
	var captured_offset: float = (car_local - frame.origin).dot(lateral_axis)

	# Se conserva la posicion lateral de la grilla como punto de partida.
	start_lateral_offset = captured_offset


# =========================================
# CONTROL PRINCIPAL DE LA IA
# =========================================

func _physics_process(delta: float) -> void:

	# 1. Validar referencia al circuito.

	if not is_instance_valid(path_follow):
		_apply_drive_output(0.0, brake_power, delta)
		return

	var path := path_follow.get_parent() as Path3D

	if path == null or path.curve == null:
		_apply_drive_output(0.0, brake_power, delta)
		return

	var curve: Curve3D = path.curve
	var path_length: float = curve.get_baked_length()

	if path_length <= 0.0:
		_apply_drive_output(0.0, brake_power, delta)
		return


	# 2. Calcular velocidad.

	var forward_direction: Vector3 = (
		global_transform.basis.z.normalized()
	)

	var forward_speed: float = linear_velocity.dot(
		forward_direction
	)

	var speed_kmh: float = absf(forward_speed) * 3.6


	# 3. Registrar tiempo y distancia desde la salida.

	race_elapsed += delta

	distance_since_launch += (
		maxf(forward_speed, 0.0) * delta
	)


	# =====================================
	# 4. INCORPORACION GRADUAL
	# =====================================

	var active_merge_distance: float = maxf(merge_distance, 160.0)

	if active_merge_distance > 0.0 and forward_speed > 0.0:

		merge_distance_travelled = minf(
			merge_distance_travelled + forward_speed * delta,
			active_merge_distance
		)

	var merge_weight: float = 1.0

	if active_merge_distance > 0.0:

		var merge_progress: float = clampf(
			merge_distance_travelled / active_merge_distance,
			0.0,
			1.0
		)

		merge_weight = (
			merge_progress
			* merge_progress
			* (3.0 - 2.0 * merge_progress)
		)


	# =====================================
	# 5. ENCONTRAR EL PUNTO MAS CERCANO
	# =====================================

	var car_on_path: Vector3 = path.to_local(
		global_position
	)

	var current_offset: float = curve.get_closest_offset(
		car_on_path
	)

	# Direccion real del trazado en el punto donde se encuentra el auto.
	# Se obtiene comparando dos puntos de la curva para no depender de la
	# convencion de orientacion de los frames de Curve3D.
	var track_forward: Vector3 = _get_path_forward(
		path,
		curve,
		current_offset,
		path_length
	)

	var vehicle_forward: Vector3 = global_transform.basis.z.normalized()
	vehicle_forward.y = 0.0
	vehicle_forward = vehicle_forward.normalized()

	var heading_alignment: float = clampf(
		vehicle_forward.dot(track_forward),
		-1.0,
		1.0
	)

	var current_progress: float = clampf(
		current_offset / path_length,
		0.0,
		1.0
	)


	# =====================================
	# 6. CALCULAR DESVIACION DE LA TRAZADA
	# =====================================

	var current_profile_offset: float = _get_profile_offset(
		current_progress
	)

	var expected_current_offset: float = lerpf(
		start_lateral_offset,
		current_profile_offset,
		merge_weight
	)

	var current_frame: Transform3D = (
		curve.sample_baked_with_rotation(current_offset)
	)

	var expected_current_local: Vector3 = (
		current_frame.origin
		+ current_frame.basis.x.normalized()
		* expected_current_offset
	)

	var expected_current_global: Vector3 = path.to_global(
		expected_current_local
	)

	var track_deviation: Vector3 = (
		global_position - expected_current_global
	)

	track_deviation.y = 0.0

	var distance_from_track: float = track_deviation.length()


	# =====================================
	# 7. ACTUALIZAR RECUPERACION
	# =====================================

	_update_recovery_state(
		distance_from_track,
		heading_alignment,
		delta
	)


	# =====================================
	# 8. CALCULAR ANTICIPACION
	# =====================================

	var active_lookahead: float = lookahead_distance

	if recovery_active:
		active_lookahead = recovery_lookahead_distance

	var target_offset: float = (
		current_offset + active_lookahead
	)

	if curve.closed:

		target_offset = fposmod(
			target_offset,
			path_length
		)

	else:

		target_offset = minf(
			target_offset,
			path_length
		)


	# =====================================
	# 9. CALCULAR TRAZADA INDIVIDUAL
	# =====================================

	var normalized_progress: float = clampf(
		target_offset / path_length,
		0.0,
		1.0
	)

	var desired_lateral_offset: float = (
		_get_profile_offset(normalized_progress)
	)

	var actual_lateral_offset: float = lerpf(
		start_lateral_offset,
		desired_lateral_offset,
		merge_weight
	)


	# =====================================
	# 10. OBTENER OBJETIVO
	# =====================================

	var target_frame: Transform3D = (
		curve.sample_baked_with_rotation(target_offset)
	)

	var target_path_local: Vector3 = (
		target_frame.origin
		+ target_frame.basis.x.normalized()
		* actual_lateral_offset
	)

	var target_global: Vector3 = path.to_global(
		target_path_local
	)


	# =====================================
	# 11. DETECTAR OBSTACULOS
	# =====================================

	var obstacle_info: Dictionary = (
		_update_obstacle_avoidance(delta)
	)

	var vehicle_left: Vector3 = (
		global_transform.basis.x.normalized()
	)

	target_global += vehicle_left * avoidance_offset


	# =====================================
	# 12. CALCULAR DIRECCION
	# =====================================

	var target_local: Vector3 = to_local(
		target_global
	)

	# Si la IA quedo mirando en sentido contrario o el objetivo le quedo
	# detras, realiza una maniobra lenta de reorientacion en vez de congelarse.
	if recovery_enabled and (
		heading_alignment < recovery_heading_threshold
		or target_local.z <= 0.1
	):
		recovery_active = true
		_perform_recovery_maneuver(
			track_forward,
			target_local,
			forward_speed,
			heading_alignment,
			delta
		)
		return

	if target_local.z <= 0.1:
		_apply_drive_output(0.0, brake_power, delta)
		steering = move_toward(
			steering,
			0.0,
			steering_response * delta
		)
		return

	warned_target_behind = false

	var target_distance: float = Vector2(
		target_local.x,
		target_local.z
	).length()

	var alpha: float = atan2(
		target_local.x,
		target_local.z
	)

	var desired_steering: float = atan(
		(2.0 * wheelbase * sin(alpha))
		/ maxf(target_distance, 0.1)
	)

	if invert_steering:
		desired_steering = -desired_steering

	desired_steering = clampf(
		desired_steering,
		-max_steer,
		max_steer
	)

	var active_steering_response: float = steering_response

	if recovery_active:
		active_steering_response = recovery_steering_response

	steering = move_toward(
		steering,
		desired_steering,
		active_steering_response * delta
	)


	# =====================================
	# 13. REGULAR VELOCIDAD EN CURVAS
	# =====================================

	var curve_factor: float = clampf(
		absf(alpha) / deg_to_rad(45.0),
		0.0,
		1.0
	)

	var desired_speed: float = lerpf(
		max_speed,
		corner_speed,
		curve_factor
	)

	if recovery_active:

		desired_speed = minf(
			desired_speed,
			recovery_speed_limit
		)


	# =====================================
	# 14. EVALUAR RIESGO DE COLISION
	# =====================================

	var obstacle_detected: bool = bool(
		obstacle_info.get("detected", false)
	)

	var obstacle_blocked: bool = bool(
		obstacle_info.get("blocked", false)
	)

	var obstacle_distance: float = float(
		obstacle_info.get("distance", forward_sensor_length)
	)

	var closing_speed: float = float(
		obstacle_info.get("closing_speed", 0.0)
	)

	var time_to_collision: float = float(
		obstacle_info.get("ttc", INF)
	)

	var emergency_brake: bool = false
	var launch_phase: bool = _is_launch_phase()

	if obstacle_detected and obstacle_blocked:

		if launch_phase:
			# En la grilla no intenta cambiarse de carril: regula la velocidad
			# segun la distancia al auto de adelante y mantiene su lugar.
			var launch_gap_speed: float = maxf(
				obstacle_distance - 2.5,
				0.0
			) * 12.0
			desired_speed = minf(desired_speed, launch_gap_speed)

			if (
				obstacle_distance <= 2.0
				or time_to_collision <= 0.40
			):
				emergency_brake = true

		elif (
			obstacle_distance <= emergency_gap_distance
			or time_to_collision <= emergency_ttc
		):

			emergency_brake = true

		elif (
			closing_speed > 0.5
			and time_to_collision <= 1.5
		):

			desired_speed = minf(
				desired_speed,
				maxf(speed_kmh - 8.0, 0.0)
			)

	elif (
		obstacle_detected
		and time_to_collision <= 0.35
	):

		emergency_brake = true


	# =====================================
	# 15. ACELERACION Y FRENADO
	# =====================================

	var target_engine_force: float = 0.0
	var target_brake: float = 0.0

	if emergency_brake:

		target_brake = obstacle_brake_power

	elif speed_kmh < desired_speed - 1.0:

		# La diferencia de velocidad determina cuanta potencia se solicita,
		# pero el limite y la rampa evitan una aceleracion instantanea.
		var speed_error: float = desired_speed - speed_kmh
		var effective_acceleration_window: float = maxf(
			acceleration_speed_window,
			36.0
		)
		var effective_max_acceleration: float = maxf(
			max_acceleration_fraction,
			0.90
		)
		var acceleration_fraction: float = clampf(
			speed_error / effective_acceleration_window,
			0.0,
			effective_max_acceleration
		)

		target_engine_force = maxf(engine_power, 65.0) * acceleration_fraction

	elif speed_kmh > desired_speed + 2.0:

		target_brake = brake_power

	_apply_drive_output(
		target_engine_force,
		target_brake,
		delta
	)


# =========================================
# OBTENER DESPLAZAMIENTO DEL PERFIL
# =========================================

func _get_profile_offset(progress: float) -> float:

	if lateral_profile != null:

		return lateral_profile.sample(
			clampf(progress, 0.0, 1.0)
		)

	return lateral_offset


# =========================================
# OBTENER DIRECCION DEL CIRCUITO
# =========================================

func _get_path_forward(
	path: Path3D,
	curve: Curve3D,
	offset: float,
	path_length: float
) -> Vector3:

	var sample_step: float = minf(2.0, maxf(path_length * 0.01, 0.25))
	var before_offset: float = offset - sample_step
	var after_offset: float = offset + sample_step

	if curve.closed:

		before_offset = fposmod(before_offset, path_length)
		after_offset = fposmod(after_offset, path_length)

	else:

		before_offset = clampf(before_offset, 0.0, path_length)
		after_offset = clampf(after_offset, 0.0, path_length)

	var before_point: Vector3 = path.to_global(
		curve.sample_baked(before_offset)
	)

	var after_point: Vector3 = path.to_global(
		curve.sample_baked(after_offset)
	)

	var direction: Vector3 = after_point - before_point
	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		direction = global_transform.basis.z

	direction.y = 0.0
	return direction.normalized()


# =========================================
# MANIOBRA DE REORIENTACION
# =========================================

func _perform_recovery_maneuver(
	track_forward: Vector3,
	target_local: Vector3,
	forward_speed: float,
	heading_alignment: float,
	delta: float
) -> void:

	var vehicle_forward: Vector3 = global_transform.basis.z.normalized()
	vehicle_forward.y = 0.0
	vehicle_forward = vehicle_forward.normalized()

	var cross_y: float = vehicle_forward.cross(track_forward).y
	var signed_angle: float = atan2(
		cross_y,
		clampf(heading_alignment, -1.0, 1.0)
	)

	var turn_direction: float = signf(signed_angle)

	# Cuando el auto mira casi exactamente al lado contrario, el producto
	# cruz puede ser practicamente cero. Elegimos un lado estable para evitar
	# que la direccion cambie de un frame al siguiente.
	if (
		absf(cross_y) < 0.05
		and heading_alignment < -0.5
	):

		if absf(target_local.x) > 0.25:
			turn_direction = signf(target_local.x)
		else:
			turn_direction = (
				1.0 if get_instance_id() % 2 == 0 else -1.0
			)

	if absf(turn_direction) < 0.01:

		if absf(target_local.x) > 0.25:
			turn_direction = signf(target_local.x)
		else:
			turn_direction = (
				1.0 if get_instance_id() % 2 == 0 else -1.0
			)

	var reverse_maneuver: bool = (
		heading_alignment < recovery_reverse_heading_threshold
		or target_local.z <= 0.1
	)

	# Al retroceder, el giro de la carroceria se produce en sentido opuesto
	# al giro de las ruedas delanteras.
	var steering_direction: float = turn_direction

	if reverse_maneuver:
		steering_direction *= -1.0

	var desired_steering: float = (
		steering_direction * max_steer
	)

	if invert_steering:
		desired_steering = -desired_steering

	steering = move_toward(
		steering,
		desired_steering,
		recovery_steering_response * delta
	)

	var target_force: float = 0.0
	var target_brake: float = 0.0
	var maneuver_speed_ms: float = recovery_maneuver_speed / 3.6

	if reverse_maneuver:

		# Primero frena si todavia avanza en el sentido equivocado.
		if forward_speed > 0.5:

			target_brake = recovery_maneuver_brake

		elif forward_speed < -maneuver_speed_ms:

			target_brake = recovery_maneuver_brake * 0.75

		else:

			target_force = -engine_power * recovery_maneuver_power

	else:

		# Si ya estaba retrocediendo, detiene el auto antes de avanzar.
		if forward_speed < -0.5:

			target_brake = recovery_maneuver_brake

		elif forward_speed > maneuver_speed_ms:

			target_brake = recovery_maneuver_brake * 0.75

		else:

			target_force = engine_power * recovery_maneuver_power

	_apply_drive_output(
		target_force,
		target_brake,
		delta
	)


# =========================================
# APLICAR MOTOR Y FRENO SUAVEMENTE
# =========================================

func _apply_drive_output(
	target_force: float,
	target_brake: float,
	delta: float
) -> void:

	if target_brake > 0.0:

		# Al frenar se corta la traccion para evitar que motor y freno
		# compitan entre si.
		current_engine_force = 0.0
		engine_force = 0.0
		brake = target_brake
		return

	brake = 0.0

	var effective_ramp_up: float = maxf(engine_force_ramp_up, 200.0)
	var effective_ramp_down: float = maxf(engine_force_ramp_down, 100.0)
	var ramp: float = effective_ramp_down

	if absf(target_force) > absf(current_engine_force):
		ramp = effective_ramp_up

	# Si cambia de avance a retroceso (o viceversa), primero lleva la
	# fuerza actual a cero antes de invertir el sentido.
	if (
		current_engine_force * target_force < 0.0
	):

		current_engine_force = move_toward(
			current_engine_force,
			0.0,
			effective_ramp_down * delta
		)

	else:

		current_engine_force = move_toward(
			current_engine_force,
			target_force,
			ramp * delta
		)

	engine_force = current_engine_force


# =========================================
# FASE DE LARGADA
# =========================================

func _is_launch_phase() -> bool:
	return (
		race_elapsed < maxf(launch_avoidance_delay, 4.5)
		or distance_since_launch < maxf(launch_avoidance_distance, 30.0)
	)


# =========================================
# ACTUALIZAR RECUPERACION
# =========================================

func _update_recovery_state(
	distance_from_track: float,
	heading_alignment: float,
	delta: float
) -> void:

	if not recovery_enabled:

		recovery_active = false
		recovery_collision_timer = 0.0
		recovery_stable_timer = 0.0

		return

	recovery_collision_timer = maxf(
		recovery_collision_timer - delta,
		0.0
	)

	var effective_merge_distance: float = maxf(merge_distance, 160.0)
	var merge_complete: bool = (
		effective_merge_distance <= 0.0
		or merge_distance_travelled >= effective_merge_distance
	)

	var heading_misaligned: bool = (
		heading_alignment < recovery_heading_threshold
	)

	# Una orientacion muy distinta a la del circuito tambien activa la
	# recuperacion, aunque el auto siga fisicamente sobre el asfalto.
	if heading_misaligned or (
		merge_complete
		and distance_from_track >= off_track_recovery_distance
	):

		recovery_active = true
		recovery_stable_timer = 0.0

	if not recovery_active:
		return

	var position_recovered: bool = (
		distance_from_track <= recovery_complete_distance
	)

	var heading_recovered: bool = (
		heading_alignment >= recovery_heading_complete_threshold
	)

	if position_recovered and heading_recovered:

		recovery_stable_timer += delta

		if (
			recovery_stable_timer >= recovery_stable_time
			and recovery_collision_timer <= 0.0
		):

			recovery_active = false
			recovery_stable_timer = 0.0

	else:

		recovery_stable_timer = 0.0


# =========================================
# INICIAR RECUPERACION POR COLISION
# =========================================

func _start_recovery() -> void:

	if not recovery_enabled:
		return

	recovery_active = true

	recovery_collision_timer = recovery_collision_hold
	recovery_stable_timer = 0.0

	avoidance_hold_timer = 0.0
	active_avoidance_side = 0.0
	avoidance_offset = 0.0


# =========================================
# DETECTAR COLISIONES FISICAS
# =========================================

func _on_body_entered(body: Node) -> void:

	if body == self:
		return

	var launch_protection: bool = _is_launch_phase()

	if body is VehicleBody3D:

		if launch_protection:
			return

		var other := body as VehicleBody3D

		var relative_speed: float = (
			linear_velocity - other.linear_velocity
		).length()

		if relative_speed < recovery_collision_min_relative_speed:
			return

		_start_recovery()

	elif body.is_in_group("race_obstacles"):

		_start_recovery()


# =========================================
# DETECCION Y EVASION DE OBSTACULOS
# =========================================

func _update_obstacle_avoidance(delta: float) -> Dictionary:

	if not avoidance_enabled:

		avoidance_hold_timer = 0.0
		active_avoidance_side = 0.0
		avoidance_offset = move_toward(
			avoidance_offset,
			0.0,
			avoidance_response * delta
		)
		return {
			"detected": false,
			"blocked": false,
			"distance": forward_sensor_length,
			"closing_speed": 0.0,
			"ttc": INF
		}

	var launch_phase: bool = _is_launch_phase()
	var forward: Vector3 = global_transform.basis.z.normalized()
	var left_axis: Vector3 = global_transform.basis.x.normalized()
	var sensor_origin: Vector3 = (
		global_position
		+ forward * sensor_forward_offset
		+ Vector3.UP * sensor_height
	)

	# Durante la largada SOLO se consulta el rayo central.
	# Los rayos laterales detectaban a los autos que estaban al lado en la
	# grilla y los interpretaban como obstaculos delante. Eso hacia que todos
	# activaran el freno al mismo tiempo y ninguno pudiera salir.
	var center_hit: Dictionary = _cast_obstacle_ray(
		sensor_origin,
		forward,
		maxf(forward_sensor_length, 32.0) if launch_phase else forward_sensor_length
	)

	var detected: bool = false
	var detected_hit: Dictionary = {}
	var distance: float = forward_sensor_length
	var closing_speed: float = 0.0
	var time_to_collision: float = INF

	if not center_hit.is_empty():
		var center_collider = center_hit.get("collider")
		var relevant_center_hit: bool = (
			center_collider is VehicleBody3D
			or (
				center_collider is Node
				and (center_collider as Node).is_in_group("race_obstacles")
			)
		)
		if relevant_center_hit:
			detected = true
			detected_hit = center_hit
			distance = _get_ray_distance(
				center_hit,
				sensor_origin,
				maxf(forward_sensor_length, 32.0) if launch_phase else forward_sensor_length
			)

	var left_clearance: float = side_sensor_length
	var right_clearance: float = side_sensor_length

	# Los laterales sirven para elegir por donde esquivar en carrera,
	# pero nunca bloquean la salida de la grilla.
	if not launch_phase:
		var left_direction: Vector3 = (forward + left_axis * sensor_spread).normalized()
		var right_direction: Vector3 = (forward - left_axis * sensor_spread).normalized()
		var left_hit: Dictionary = _cast_obstacle_ray(
			sensor_origin, left_direction, side_sensor_length
		)
		var right_hit: Dictionary = _cast_obstacle_ray(
			sensor_origin, right_direction, side_sensor_length
		)
		left_clearance = _get_ray_distance(
			left_hit, sensor_origin, side_sensor_length
		)
		right_clearance = _get_ray_distance(
			right_hit, sensor_origin, side_sensor_length
		)

	if detected:
		var collider = detected_hit.get("collider")
		var other_velocity: Vector3 = Vector3.ZERO
		if collider is RigidBody3D:
			other_velocity = (collider as RigidBody3D).linear_velocity
		elif collider is CharacterBody3D:
			other_velocity = (collider as CharacterBody3D).velocity

		var relative_velocity: Vector3 = linear_velocity - other_velocity
		closing_speed = maxf(relative_velocity.dot(forward), 0.0)
		if closing_speed > 0.1:
			time_to_collision = distance / closing_speed

	var trigger_distance: float = avoidance_trigger_distance
	var trigger_ttc: float = avoidance_ttc_threshold
	if launch_phase:
		trigger_distance = maxf(trigger_distance, 8.0)
		trigger_ttc = maxf(trigger_ttc, 2.0)

	var threat: bool = (
		detected
		and (
			distance <= trigger_distance
			or time_to_collision <= trigger_ttc
		)
	)

	var blocked: bool = false
	if threat:
		avoidance_hold_timer = avoidance_hold_time
		if launch_phase:
			# Mantiene el carril y regula la velocidad solo si hay un auto u
			# obstaculo REAL directamente delante del paragolpes.
			active_avoidance_side = 0.0
			blocked = true
		else:
			var selected_side: float = _choose_escape_side(
				left_clearance,
				right_clearance
			)
			if selected_side != 0.0:
				active_avoidance_side = selected_side
			else:
				active_avoidance_side = 0.0
				blocked = true
	else:
		avoidance_hold_timer = maxf(avoidance_hold_timer - delta, 0.0)
		if avoidance_hold_timer <= 0.0:
			active_avoidance_side = 0.0

	var desired_offset: float = 0.0
	if active_avoidance_side != 0.0:
		desired_offset = active_avoidance_side * avoidance_offset_distance

	avoidance_offset = move_toward(
		avoidance_offset,
		desired_offset,
		avoidance_response * delta
	)

	return {
		"detected": threat,
		"blocked": blocked,
		"distance": distance,
		"closing_speed": closing_speed,
		"ttc": time_to_collision
	}


# =========================================
# ELEGIR EL LADO CON MAS ESPACIO
# =========================================

func _choose_escape_side(
	left_clearance: float,
	right_clearance: float
) -> float:

	var left_available: bool = (
		left_clearance >= minimum_escape_clearance
	)

	var right_available: bool = (
		right_clearance >= minimum_escape_clearance
	)

	if left_available and right_available:

		if absf(left_clearance - right_clearance) > 0.75:
			return 1.0 if left_clearance > right_clearance else -1.0

		# Si ambos lados estan igual de libres, reparte los bots entre ambos.
		# La posicion lateral de largada tiene prioridad; si es central,
		# se usa un desempate estable por instancia.
		if absf(start_lateral_offset) > 0.5:
			return signf(start_lateral_offset)

		return 1.0 if get_instance_id() % 2 == 0 else -1.0

	elif left_available:

		return 1.0

	elif right_available:

		return -1.0

	return 0.0


# =========================================
# LANZAR RAYO DE DETECCION
# =========================================

func _cast_obstacle_ray(
	origin: Vector3,
	direction: Vector3,
	ray_length: float
) -> Dictionary:

	var exclude: Array[RID] = own_collision_rids.duplicate()
	if exclude.is_empty():
		exclude.append(get_rid())

	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * ray_length,
		avoidance_collision_mask,
		exclude
	)

	query.collide_with_bodies = true
	query.collide_with_areas = false

	return get_world_3d().direct_space_state.intersect_ray(
		query
	)


# =========================================
# CALCULAR DISTANCIA DEL RAYO
# =========================================

func _get_ray_distance(
	hit: Dictionary,
	origin: Vector3,
	ray_length: float
) -> float:

	if hit.is_empty():
		return ray_length

	var hit_position: Vector3 = hit["position"]

	return origin.distance_to(hit_position)
