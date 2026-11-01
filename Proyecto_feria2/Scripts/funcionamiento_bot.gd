extends VehicleBody3D


# =========================================
# REFERENCIA AL CIRCUITO
# =========================================

@export var path_follow: PathFollow3D


# =========================================
# CONFIGURACION DEL MOTOR
# =========================================

@export_group("Motor")

@export var engine_power: float = 7500.0
@export var brake_power: float = 42.0
@export var max_speed: float = 120.0
@export var corner_speed: float = 55.0

# Segundos que tarda la fuerza en pasar de 0 a engine_power (en carrera)
# y en volver a 0 al soltar el acelerador.
@export var throttle_rise_time: float = 1.2
@export var throttle_fall_time: float = 0.4

# Cuanta diferencia de velocidad (km/h) hace falta para pedir potencia maxima.
@export var acceleration_speed_window: float = 36.0
@export_range(0.1, 1.0, 0.05) var max_acceleration_fraction: float = 0.90
# Potencia minima mientras el auto esta por debajo de la velocidad objetivo.
@export_range(0.0, 0.5, 0.01) var min_acceleration_fraction: float = 0.15


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

@export_group("Trazada individual")

@export_range(-5.0, 5.0, 0.1) var lateral_offset: float = 0.0
@export var lateral_profile: Curve
@export_range(-5.0, 5.0, 0.1) var start_lateral_offset: float = 0.0
@export_range(0.0, 300.0, 1.0) var merge_distance: float = 160.0

# Captura el carril real que ocupa cada auto en la grilla (en el primer frame).
@export var capture_start_grid_offset: bool = true

var merge_distance_travelled: float = 0.0
var grid_offset_captured: bool = false


# =========================================
# EVASION DE OBSTACULOS
# =========================================

@export_group("Evasion de obstaculos")

@export var avoidance_enabled: bool = true
@export var avoidance_collision_mask: int = 4294967295

# Que se considera obstaculo: autos (VehicleBody3D), cuerpos fisicos
# (RigidBody3D / CharacterBody3D) y todo nodo que este en alguno de estos grupos.
# Si tus obstaculos son StaticBody3D, agregalos al grupo "race_obstacles".
@export var obstacle_groups: Array[String] = ["race_obstacles"]
@export var detect_physics_bodies: bool = true

@export var forward_sensor_length: float = 45.0
@export var side_sensor_length: float = 14.0
# Separacion lateral de los rayos frontales (aprox. la mitad del ancho del auto).
@export var sensor_half_width: float = 0.95

@export var sensor_forward_offset: float = 1.5
@export var sensor_height: float = 0.65
@export var sensor_spread: float = 0.30

@export var avoidance_trigger_distance: float = 6.0
@export var avoidance_ttc_threshold: float = 2.5

# Espacio LATERAL libre (metros) necesario para animarse a esquivar por un lado.
@export var minimum_escape_clearance: float = 3.0

@export var avoidance_offset_distance: float = 2.2
@export var avoidance_response: float = 4.0
@export var avoidance_hold_time: float = 0.5
# Metros extra que mantiene el desvio despues de pasar el obstaculo.
@export var avoidance_pass_margin: float = 7.0
# Segundos esperando bloqueado ante un obstaculo quieto antes de forzar el paso.
@export var blocked_patience: float = 2.5

# Frenado: desaceleracion que se supone que el auto logra (m/s2) y distancia
# a la que busca quedar detras de un obstaculo.
@export var assumed_brake_decel: float = 9.0
@export var avoidance_stop_gap: float = 3.5
# Cuando esta esquivando permite ir mas rapido que si tuviera que frenar.
@export var dodge_speed_factor: float = 1.8
@export var min_dodge_speed: float = 35.0

@export var emergency_gap_distance: float = 2.0
@export var emergency_ttc: float = 0.45
# Freno maximo ante obstaculos (tiene que ser mayor que brake_power).
@export var obstacle_brake_power: float = 65.0

var avoidance_offset: float = 0.0
var active_avoidance_side: float = 0.0
var avoidance_hold_timer: float = 0.0
var avoidance_pass_remaining: float = 0.0
var last_obstacle_speed: float = 0.0
var blocked_timer: float = 0.0


# =========================================
# SALIDA (GRILLA)
# =========================================

@export_group("Salida")

# La proteccion de salida dura mientras (tiempo < delay O distancia < distance),
# pero nunca mas que launch_max_time.
@export var launch_avoidance_delay: float = 3.5
@export var launch_avoidance_distance: float = 30.0
@export var launch_max_time: float = 8.0

# Salida: potencia inicial, tope de velocidad y que tan rapido sube la fuerza.
# Estos limites se liberan gradualmente a lo largo de launch_ramp_distance.
@export_range(0.1, 1.0, 0.05) var launch_power_scale: float = 0.85
@export var launch_speed_cap: float = 95.0
@export var launch_throttle_time: float = 0.8
@export var launch_ramp_distance: float = 80.0

@export var recovery_collision_min_relative_speed: float = 4.0

var race_elapsed: float = 0.0
var distance_since_launch: float = 0.0
var launch_blend: float = 0.0


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

@export_range(-1.0, 1.0, 0.05) var recovery_heading_threshold: float = 0.15
@export_range(-1.0, 1.0, 0.05) var recovery_heading_complete_threshold: float = 0.75

# Maniobra lenta para reorientarse despues de un trompo o choque.
@export var recovery_maneuver_speed: float = 12.0
@export_range(0.05, 1.0, 0.05) var recovery_maneuver_power: float = 0.35
@export var recovery_maneuver_brake: float = 18.0
@export var recovery_reverse_heading_threshold: float = 0.0

@export_subgroup("Auto trabado")
@export var stuck_detection_enabled: bool = true
@export var stuck_speed_threshold: float = 3.0   # km/h
@export var stuck_time: float = 2.0              # segundos casi parado
@export var unstick_reverse_time: float = 1.3    # segundos de marcha atras
@export_range(0.1, 1.0, 0.05) var unstick_power: float = 0.6

var recovery_active: bool = false
var recovery_collision_timer: float = 0.0
var recovery_stable_timer: float = 0.0
var current_engine_force: float = 0.0
var stuck_timer: float = 0.0
var unstick_timer: float = 0.0


# =========================================
# DEBUG
# =========================================

@export_group("Debug")

# Activalo en UN auto para ver en la consola que esta haciendo.
@export var debug_enabled: bool = false

var debug_state: String = ""
var debug_timer: float = 0.0


# =========================================
# VARIABLES GENERALES
# =========================================

var own_collision_rids: Array[RID] = []


# =========================================
# INICIALIZACION
# =========================================

func _ready() -> void:

	if path_follow == null:
		push_error("AI: No se asigno PathFollow3D.")

	# Evita que el auto se "duerma" en la grilla y el motor no lo despierte.
	can_sleep = false
	sleeping = false

	contact_monitor = true
	max_contacts_reported = 8

	own_collision_rids.clear()
	own_collision_rids.append(get_rid())
	for child in find_children("*", "CollisionObject3D", true, false):
		if child is CollisionObject3D:
			own_collision_rids.append((child as CollisionObject3D).get_rid())

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _capture_starting_grid_offset(path: Path3D, curve: Curve3D) -> void:

	grid_offset_captured = true

	if not capture_start_grid_offset:
		return

	var car_local: Vector3 = path.to_local(global_position)
	var closest_offset: float = curve.get_closest_offset(car_local)
	var frame: Transform3D = curve.sample_baked_with_rotation(closest_offset)
	var lateral_axis: Vector3 = frame.basis.x.normalized()

	start_lateral_offset = (car_local - frame.origin).dot(lateral_axis)


# =========================================
# CONTROL PRINCIPAL DE LA IA
# =========================================

func _physics_process(delta: float) -> void:

	# 1. Validar referencia al circuito.

	var path: Path3D = null

	if is_instance_valid(path_follow):
		path = path_follow.get_parent() as Path3D

	if path == null or path.curve == null:
		debug_state = "SIN_PATH"
		_apply_drive_output(0.0, brake_power, delta)
		return

	var curve: Curve3D = path.curve
	var path_length: float = curve.get_baked_length()

	if path_length <= 0.0:
		debug_state = "PATH_VACIO"
		_apply_drive_output(0.0, brake_power, delta)
		return

	if not grid_offset_captured:
		_capture_starting_grid_offset(path, curve)


	# 2. Calcular velocidad.

	var forward_direction: Vector3 = global_transform.basis.z.normalized()
	var forward_speed: float = linear_velocity.dot(forward_direction)
	var speed_kmh: float = absf(forward_speed) * 3.6


	# 3. Tiempo y distancia desde la salida.

	race_elapsed += delta
	distance_since_launch += maxf(forward_speed, 0.0) * delta
	launch_blend = _get_launch_blend()

	_debug_tick(delta, speed_kmh)


	# 4. Incorporacion gradual a la trazada propia.

	if merge_distance > 0.0 and forward_speed > 0.0:
		merge_distance_travelled = minf(
			merge_distance_travelled + forward_speed * delta,
			merge_distance
		)

	var merge_weight: float = 1.0

	if merge_distance > 0.0:
		var merge_progress: float = clampf(
			merge_distance_travelled / merge_distance,
			0.0,
			1.0
		)
		merge_weight = merge_progress * merge_progress * (3.0 - 2.0 * merge_progress)


	# 5. Punto mas cercano y orientacion respecto a la pista.

	var car_on_path: Vector3 = path.to_local(global_position)
	var current_offset: float = curve.get_closest_offset(car_on_path)

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


	# 6. Desviacion respecto a la trazada esperada.

	var current_progress: float = clampf(current_offset / path_length, 0.0, 1.0)

	var expected_current_offset: float = lerpf(
		start_lateral_offset,
		_get_profile_offset(current_progress),
		merge_weight
	)

	var current_frame: Transform3D = curve.sample_baked_with_rotation(current_offset)

	var expected_current_global: Vector3 = path.to_global(
		current_frame.origin
		+ current_frame.basis.x.normalized() * expected_current_offset
	)

	var track_deviation: Vector3 = global_position - expected_current_global
	track_deviation.y = 0.0
	var distance_from_track: float = track_deviation.length()


	# 7. Actualizar recuperacion.

	_update_recovery_state(distance_from_track, heading_alignment, delta)


	# 8. Anticipacion.

	var active_lookahead: float = lookahead_distance

	if recovery_active:
		active_lookahead = recovery_lookahead_distance

	var target_offset: float = current_offset + active_lookahead

	if curve.closed:
		target_offset = fposmod(target_offset, path_length)
	else:
		target_offset = minf(target_offset, path_length)


	# 9. Trazada individual en el punto objetivo.

	var normalized_progress: float = clampf(target_offset / path_length, 0.0, 1.0)

	var actual_lateral_offset: float = lerpf(
		start_lateral_offset,
		_get_profile_offset(normalized_progress),
		merge_weight
	)


	# 10. Punto objetivo.

	var target_frame: Transform3D = curve.sample_baked_with_rotation(target_offset)

	var target_global: Vector3 = path.to_global(
		target_frame.origin
		+ target_frame.basis.x.normalized() * actual_lateral_offset
	)


	# 11. Obstaculos.

	var obstacle_info: Dictionary = _update_obstacle_avoidance(delta)

	target_global += global_transform.basis.x.normalized() * avoidance_offset

	var obstacle_detected: bool = bool(obstacle_info.get("detected", false))
	var obstacle_blocked: bool = bool(obstacle_info.get("blocked", false))
	var obstacle_distance: float = float(obstacle_info.get("distance", forward_sensor_length))
	var closing_speed: float = float(obstacle_info.get("closing_speed", 0.0))
	var time_to_collision: float = float(obstacle_info.get("ttc", INF))
	var obstacle_speed: float = float(obstacle_info.get("obstacle_speed", 0.0))
	var dodging: bool = bool(obstacle_info.get("dodging", false))

	var launch_phase: bool = _is_launch_phase()


	# 12. Deteccion de auto trabado.

	var waiting_behind_car: bool = (
		obstacle_detected and obstacle_blocked and obstacle_distance < 4.0
	)
	_update_stuck_state(speed_kmh, waiting_behind_car, launch_phase, delta)

	var target_local: Vector3 = to_local(target_global)
	var force_reverse: bool = unstick_timer > 0.0


	# 13. Maniobra de recuperacion (trompo, mirando al reves, trabado).

	if recovery_enabled and (
		force_reverse
		or heading_alignment < recovery_heading_threshold
		or target_local.z <= 0.1
	):
		recovery_active = true
		debug_state = "UNSTICK" if force_reverse else "RECUPERACION"
		_perform_recovery_maneuver(
			track_forward,
			target_local,
			forward_speed,
			heading_alignment,
			force_reverse,
			delta
		)
		return

	if target_local.z <= 0.1:
		debug_state = "OBJETIVO_ATRAS"
		_apply_drive_output(0.0, brake_power, delta)
		steering = move_toward(steering, 0.0, steering_response * delta)
		return


	# 14. Direccion (pure pursuit).

	var target_distance: float = Vector2(target_local.x, target_local.z).length()
	var alpha: float = atan2(target_local.x, target_local.z)

	var desired_steering: float = atan(
		(2.0 * wheelbase * sin(alpha)) / maxf(target_distance, 0.1)
	)

	if invert_steering:
		desired_steering = -desired_steering

	desired_steering = clampf(desired_steering, -max_steer, max_steer)

	var active_steering_response: float = steering_response

	if recovery_active:
		active_steering_response = recovery_steering_response

	steering = move_toward(steering, desired_steering, active_steering_response * delta)


	# 15. Velocidad objetivo.

	var curve_factor: float = clampf(absf(alpha) / deg_to_rad(45.0), 0.0, 1.0)

	var desired_speed: float = lerpf(max_speed, corner_speed, curve_factor)

	# Salida: el limite se libera gradualmente.
	desired_speed = minf(
		desired_speed,
		lerpf(launch_speed_cap, max_speed, launch_blend)
	)

	if recovery_active:
		desired_speed = minf(desired_speed, recovery_speed_limit)


	# 16. Riesgo de colision.

	var emergency_brake: bool = false
	var obstacle_limited: bool = false

	if obstacle_detected:

		if launch_phase:
			# En la grilla mantiene el lugar y regula la velocidad segun la
			# distancia al auto de adelante (siempre avanza un poco si hay lugar).
			if obstacle_distance <= 2.0 or time_to_collision <= 0.40:
				emergency_brake = true
			else:
				var launch_gap_speed: float = maxf(
					(obstacle_distance - 2.5) * 12.0,
					6.0
				)
				desired_speed = minf(desired_speed, launch_gap_speed)

		else:
			# En carrera: limita la velocidad segun la distancia disponible
			# para frenar (o esquivar) antes de llegar al obstaculo.
			obstacle_limited = true

			var gap: float = maxf(obstacle_distance - avoidance_stop_gap, 0.0)
			var allowed_closing: float = sqrt(2.0 * assumed_brake_decel * gap)

			if dodging:
				allowed_closing *= dodge_speed_factor

			var allowed_kmh: float = (
				maxf(obstacle_speed, 0.0) + allowed_closing
			) * 3.6

			if dodging:
				allowed_kmh = maxf(allowed_kmh, min_dodge_speed)

			desired_speed = minf(desired_speed, allowed_kmh)

			var stop_room: float = maxf(obstacle_distance - 1.0, 0.1)
			var needed_decel: float = 0.0

			if closing_speed > 0.5:
				needed_decel = (closing_speed * closing_speed) / (2.0 * stop_room)

			var panic_ttc: float = 0.35 if dodging else emergency_ttc

			if (
				obstacle_distance <= emergency_gap_distance
				or time_to_collision <= panic_ttc
			):
				emergency_brake = true

			elif not dodging and needed_decel > assumed_brake_decel * 1.2:
				emergency_brake = true


	# 17. Aceleracion y frenado.

	var target_engine_force: float = 0.0
	var target_brake: float = 0.0

	if emergency_brake:

		debug_state = "FRENO_EMERGENCIA"
		target_brake = maxf(obstacle_brake_power, brake_power)

	elif speed_kmh < desired_speed - 1.0:

		var speed_error: float = desired_speed - speed_kmh
		var acceleration_fraction: float = clampf(
			speed_error / maxf(acceleration_speed_window, 1.0),
			min_acceleration_fraction,
			max_acceleration_fraction
		)

		target_engine_force = (
			engine_power
			* acceleration_fraction
			* lerpf(launch_power_scale, 1.0, launch_blend)
		)

		debug_state = "ACELERANDO (salida)" if launch_phase else "ACELERANDO"

	elif speed_kmh > desired_speed + 2.0:

		debug_state = "FRENANDO"
		target_brake = brake_power

		if obstacle_limited:
			# Cuanto mas pasado de velocidad, mas fuerte frena.
			var urgency: float = clampf(
				(speed_kmh - desired_speed) / 25.0,
				0.0,
				1.0
			)
			target_brake = lerpf(
				brake_power,
				maxf(obstacle_brake_power, brake_power),
				urgency
			)
			debug_state = "FRENANDO (obstaculo)"

	else:

		debug_state = "MANTENIENDO"

	if dodging and not emergency_brake:
		debug_state += " [esquivando]"

	_apply_drive_output(target_engine_force, target_brake, delta)


# =========================================
# PERFIL LATERAL
# =========================================

func _get_profile_offset(progress: float) -> float:

	if lateral_profile != null:
		return lateral_profile.sample(clampf(progress, 0.0, 1.0))

	return lateral_offset


# =========================================
# DIRECCION DEL CIRCUITO
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

	var before_point: Vector3 = path.to_global(curve.sample_baked(before_offset))
	var after_point: Vector3 = path.to_global(curve.sample_baked(after_offset))

	var direction: Vector3 = after_point - before_point
	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		direction = global_transform.basis.z

	direction.y = 0.0
	return direction.normalized()


# =========================================
# FASE DE SALIDA
# =========================================

func _is_launch_phase() -> bool:

	if race_elapsed >= launch_max_time:
		return false

	return (
		race_elapsed < launch_avoidance_delay
		or distance_since_launch < launch_avoidance_distance
	)


func _get_launch_blend() -> float:

	if launch_ramp_distance <= 0.0:
		return 1.0

	var t: float = clampf(distance_since_launch / launch_ramp_distance, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# =========================================
# DETECCION DE AUTO TRABADO
# =========================================

func _update_stuck_state(
	speed_kmh: float,
	waiting_behind_car: bool,
	launch_phase: bool,
	delta: float
) -> void:

	if unstick_timer > 0.0:
		unstick_timer = maxf(unstick_timer - delta, 0.0)
		stuck_timer = 0.0
		return

	if not stuck_detection_enabled or not recovery_enabled:
		stuck_timer = 0.0
		return

	# En la grilla, o esperando legitimamente a un auto de adelante, no cuenta.
	if launch_phase or waiting_behind_car:
		stuck_timer = 0.0
		return

	if speed_kmh < stuck_speed_threshold:

		stuck_timer += delta

		if stuck_timer >= stuck_time:
			unstick_timer = unstick_reverse_time
			stuck_timer = 0.0
			recovery_active = true
			recovery_stable_timer = 0.0

	else:
		stuck_timer = 0.0


# =========================================
# MANIOBRA DE REORIENTACION
# =========================================

func _stable_side(preferred: float) -> float:

	if absf(preferred) > 0.25:
		return signf(preferred)

	return 1.0 if get_instance_id() % 2 == 0 else -1.0


func _perform_recovery_maneuver(
	track_forward: Vector3,
	target_local: Vector3,
	forward_speed: float,
	heading_alignment: float,
	force_reverse: bool,
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

	# Casi exactamente al reves (o ya alineado): elige un lado estable
	# para que la direccion no cambie de un frame al siguiente.
	if (
		absf(turn_direction) < 0.01
		or (absf(cross_y) < 0.05 and heading_alignment < -0.5)
	):
		turn_direction = _stable_side(target_local.x)

	var reverse_maneuver: bool = (
		force_reverse
		or heading_alignment < recovery_reverse_heading_threshold
		or target_local.z <= 0.1
	)

	# Al retroceder, la carroceria gira en sentido opuesto a las ruedas.
	var steering_direction: float = turn_direction

	if reverse_maneuver:
		steering_direction *= -1.0

	var desired_steering: float = steering_direction * max_steer

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

		var reverse_power: float = unstick_power if force_reverse else recovery_maneuver_power

		if forward_speed > 0.5:
			target_brake = recovery_maneuver_brake
		elif forward_speed < -maneuver_speed_ms:
			target_brake = recovery_maneuver_brake * 0.75
		else:
			target_force = -engine_power * reverse_power

	else:

		if forward_speed < -0.5:
			target_brake = recovery_maneuver_brake
		elif forward_speed > maneuver_speed_ms:
			target_brake = recovery_maneuver_brake * 0.75
		else:
			target_force = engine_power * recovery_maneuver_power

	_apply_drive_output(target_force, target_brake, delta)


# =========================================
# MOTOR Y FRENO SUAVES
# =========================================

func _apply_drive_output(
	target_force: float,
	target_brake: float,
	delta: float
) -> void:

	if target_brake > 0.0:
		# Al frenar se corta la traccion para que motor y freno no compitan.
		current_engine_force = 0.0
		engine_force = 0.0
		brake = target_brake
		return

	brake = 0.0

	# Rampas definidas en segundos: no dependen del valor de engine_power.
	var rise_time: float = lerpf(launch_throttle_time, throttle_rise_time, launch_blend)
	var ramp_up: float = engine_power / maxf(rise_time, 0.05)
	var ramp_down: float = engine_power / maxf(throttle_fall_time, 0.05)

	var ramp: float = ramp_down

	if absf(target_force) > absf(current_engine_force):
		ramp = ramp_up

	# Si cambia de avance a retroceso (o al reves), pasa primero por cero.
	if current_engine_force * target_force < 0.0:
		current_engine_force = move_toward(
			current_engine_force,
			0.0,
			ramp_down * delta
		)
	else:
		current_engine_force = move_toward(
			current_engine_force,
			target_force,
			ramp * delta
		)

	engine_force = current_engine_force


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

	recovery_collision_timer = maxf(recovery_collision_timer - delta, 0.0)

	var merge_complete: bool = (
		merge_distance <= 0.0
		or merge_distance_travelled >= merge_distance
	)

	var heading_misaligned: bool = heading_alignment < recovery_heading_threshold

	if heading_misaligned or (
		merge_complete
		and distance_from_track >= off_track_recovery_distance
	):
		recovery_active = true
		recovery_stable_timer = 0.0

	if not recovery_active:
		return

	var position_recovered: bool = distance_from_track <= recovery_complete_distance
	var heading_recovered: bool = heading_alignment >= recovery_heading_complete_threshold

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


func _start_recovery() -> void:

	if not recovery_enabled:
		return

	recovery_active = true
	recovery_collision_timer = recovery_collision_hold
	recovery_stable_timer = 0.0

	avoidance_hold_timer = 0.0
	avoidance_pass_remaining = 0.0
	blocked_timer = 0.0
	active_avoidance_side = 0.0
	avoidance_offset = 0.0


# =========================================
# COLISIONES FISICAS
# =========================================

func _on_body_entered(body: Node) -> void:

	if body == self:
		return

	if body is VehicleBody3D:

		if _is_launch_phase():
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
# QUE CUENTA COMO OBSTACULO
# =========================================

func _is_obstacle(collider: Object) -> bool:

	if collider == null or collider == self:
		return false

	if collider is VehicleBody3D:
		return true

	if detect_physics_bodies and (
		collider is RigidBody3D
		or collider is CharacterBody3D
	):
		return true

	if collider is Node:
		var node := collider as Node
		for group_name in obstacle_groups:
			if node.is_in_group(group_name):
				return true

	return false


# =========================================
# DETECCION Y EVASION DE OBSTACULOS
# =========================================

func _update_obstacle_avoidance(delta: float) -> Dictionary:

	if not avoidance_enabled:

		avoidance_hold_timer = 0.0
		avoidance_pass_remaining = 0.0
		blocked_timer = 0.0
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
			"ttc": INF,
			"obstacle_speed": 0.0,
			"dodging": false
		}

	var launch_phase: bool = _is_launch_phase()
	var forward: Vector3 = global_transform.basis.z.normalized()
	var left_axis: Vector3 = global_transform.basis.x.normalized()
	var own_forward_speed: float = linear_velocity.dot(forward)

	var sensor_origin: Vector3 = (
		global_position
		+ forward * sensor_forward_offset
		+ Vector3.UP * sensor_height
	)

	var ray_length: float = forward_sensor_length

	if launch_phase:
		ray_length = maxf(forward_sensor_length, 32.0)

	# Durante la salida SOLO se usa el rayo central (los laterales detectaban
	# a los autos vecinos de la grilla y bloqueaban a todos).
	# En carrera se usan 3 rayos paralelos para cubrir todo el ancho del auto.
	var lateral_offsets: Array = [0.0]

	if not launch_phase:
		lateral_offsets = [0.0, sensor_half_width, -sensor_half_width]

	var detected: bool = false
	var distance: float = forward_sensor_length
	var closest_collider: Object = null
	var hit_on_left: bool = false
	var hit_on_right: bool = false

	for lateral in lateral_offsets:

		var lateral_value: float = lateral
		var ray_origin: Vector3 = sensor_origin + left_axis * lateral_value
		var hit: Dictionary = _cast_obstacle_ray(ray_origin, forward, ray_length)

		if hit.is_empty():
			continue

		var hit_collider: Object = hit.get("collider")

		if not _is_obstacle(hit_collider):
			continue

		var hit_distance: float = _get_ray_distance(hit, ray_origin, ray_length)

		if lateral_value > 0.01:
			hit_on_left = true
		elif lateral_value < -0.01:
			hit_on_right = true

		if not detected or hit_distance < distance:
			detected = true
			distance = hit_distance
			closest_collider = hit_collider

	# Hacia que lado esta el obstaculo (+1 izquierda, -1 derecha, 0 centrado).
	var side_hint: float = 0.0

	if hit_on_left and not hit_on_right:
		side_hint = 1.0
	elif hit_on_right and not hit_on_left:
		side_hint = -1.0

	# Espacio lateral libre a cada lado (en metros, medido desde el centro).
	var left_clearance: float = 0.0
	var right_clearance: float = 0.0

	if not launch_phase:
		var side_factor: float = sensor_spread / sqrt(1.0 + sensor_spread * sensor_spread)
		var left_direction: Vector3 = (forward + left_axis * sensor_spread).normalized()
		var right_direction: Vector3 = (forward - left_axis * sensor_spread).normalized()
		var left_hit: Dictionary = _cast_obstacle_ray(
			sensor_origin, left_direction, side_sensor_length
		)
		var right_hit: Dictionary = _cast_obstacle_ray(
			sensor_origin, right_direction, side_sensor_length
		)
		left_clearance = _get_ray_distance(left_hit, sensor_origin, side_sensor_length) * side_factor
		right_clearance = _get_ray_distance(right_hit, sensor_origin, side_sensor_length) * side_factor

	var closing_speed: float = 0.0
	var time_to_collision: float = INF
	var obstacle_speed: float = 0.0

	if detected:
		var other_velocity: Vector3 = Vector3.ZERO

		if closest_collider is RigidBody3D:
			other_velocity = (closest_collider as RigidBody3D).linear_velocity
		elif closest_collider is CharacterBody3D:
			other_velocity = (closest_collider as CharacterBody3D).velocity

		obstacle_speed = other_velocity.dot(forward)
		closing_speed = maxf(own_forward_speed - obstacle_speed, 0.0)

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
		avoidance_pass_remaining = distance + avoidance_pass_margin
		last_obstacle_speed = obstacle_speed

		if launch_phase:
			active_avoidance_side = 0.0
			blocked = true
		else:
			var selected_side: float = _choose_escape_side(
				left_clearance,
				right_clearance,
				side_hint
			)

			if selected_side != 0.0:
				active_avoidance_side = selected_side
				blocked_timer = 0.0
			else:
				blocked_timer += delta

				# Obstaculo quieto y sin salida clara: despues de esperar,
				# se fuerza el paso por el lado mas libre.
				if blocked_timer >= blocked_patience and absf(obstacle_speed) < 1.5:
					active_avoidance_side = 1.0 if left_clearance >= right_clearance else -1.0
				else:
					active_avoidance_side = 0.0
					blocked = true

	else:

		blocked_timer = 0.0
		avoidance_hold_timer = maxf(avoidance_hold_timer - delta, 0.0)

		# Mantiene el desvio hasta haber pasado el obstaculo.
		var approach_speed: float = maxf(own_forward_speed - last_obstacle_speed, 0.0)
		avoidance_pass_remaining = maxf(
			avoidance_pass_remaining - approach_speed * delta,
			0.0
		)

		if avoidance_hold_timer <= 0.0 and avoidance_pass_remaining <= 0.0:
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
		"ttc": time_to_collision,
		"obstacle_speed": obstacle_speed,
		"dodging": active_avoidance_side != 0.0
	}


func _choose_escape_side(
	left_clearance: float,
	right_clearance: float,
	side_hint: float
) -> float:

	var left_available: bool = left_clearance >= minimum_escape_clearance
	var right_available: bool = right_clearance >= minimum_escape_clearance

	# Si ya eligio un lado y sigue disponible, lo mantiene (evita zigzag).
	if active_avoidance_side > 0.0 and left_available:
		return 1.0

	if active_avoidance_side < 0.0 and right_available:
		return -1.0

	if left_available and right_available:

		# Esquiva hacia el lado contrario al del obstaculo.
		if side_hint != 0.0:
			return -side_hint

		if absf(left_clearance - right_clearance) > 0.4:
			return 1.0 if left_clearance > right_clearance else -1.0

		if absf(start_lateral_offset) > 0.5:
			return signf(start_lateral_offset)

		return 1.0 if get_instance_id() % 2 == 0 else -1.0

	elif left_available:
		return 1.0

	elif right_available:
		return -1.0

	return 0.0


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

	return get_world_3d().direct_space_state.intersect_ray(query)


func _get_ray_distance(
	hit: Dictionary,
	origin: Vector3,
	ray_length: float
) -> float:

	if hit.is_empty():
		return ray_length

	var hit_position: Vector3 = hit["position"]
	return origin.distance_to(hit_position)


# =========================================
# DEBUG
# =========================================

func _debug_tick(delta: float, speed_kmh: float) -> void:

	if not debug_enabled:
		return

	debug_timer += delta

	if debug_timer < 0.5:
		return

	debug_timer = 0.0

	print(
		"[", name, "] ", debug_state,
		" | v=", snappedf(speed_kmh, 0.1), " km/h",
		" | engine=", snappedf(engine_force, 0.1),
		" | brake=", snappedf(brake, 0.1),
		" | salida=", _is_launch_phase(),
		" | recup=", recovery_active,
		" | t=", snappedf(race_elapsed, 0.1)
	)
