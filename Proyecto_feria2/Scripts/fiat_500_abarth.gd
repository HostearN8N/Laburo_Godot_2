extends VehicleBody3D

const MAX_STEER = 0.5
const ENGINE_POWER = 10500.0


const GEAR_MAX_SPEED: Array[float] = [50.0, 85.0, 125.0, 165.0, 200.0]  # km/h máx. de 1ª a 5ª
const GEAR_TORQUE: Array[float] = [1.0, 0.75, 0.55, 0.42, 0.33]         # fuerza relativa por marcha
const REVERSE_MAX_SPEED := 30.0   # km/h máx. en reversa
const UPSHIFT_AT := 0.92          # sube al 92% de la vel. máx. de la marcha
const DOWNSHIFT_AT := 0.60        # baja al 60% de la vel. máx. de la marcha anterior
const SHIFT_TIME := 0.5           # segundos sin tracción durante el cambio
const BRAKE_POWER := 20.0         # fuerza de freno

@onready var camera_pivot = $Camera_Pivot
@onready var camera_3d = $Camera_Pivot/Camera3D
@onready var reverse_camera = $Camera_Pivot/Reverse_camera

var target_look_at: Vector3 = Vector3.ZERO
var current_gear := 1     # -1 = reversa, 1 a 5 = marchas
var speed_kmh := 0.0
var shift_timer := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_look_at = global_position

func _physics_process(delta: float) -> void:
	
	steering = move_toward(steering, Input.get_axis("ui_right", "ui_left") * MAX_STEER, delta * 2.5)
	
	var throttle := Input.get_axis("ui_down", "ui_up")
	_update_gearbox(delta, throttle)
	engine_force = _get_engine_force(throttle)

	# Freno: se activa si la tecla va contra el sentido de marcha
	var braking := (current_gear > 0 and throttle < 0.0) or (current_gear == -1 and throttle > 0.0)
	brake = BRAKE_POWER if braking else 0.0
	
	camera_pivot.global_position = camera_pivot.global_position.lerp(global_position, delta * 20.0)
	camera_pivot.transform = camera_pivot.transform.interpolate_with(transform, delta * 5.0)
	
	target_look_at = target_look_at.lerp(global_position + linear_velocity, delta * 5.0)
	camera_3d.look_at(target_look_at)
	reverse_camera.look_at(target_look_at)
	
	_check_camera_switch()

func _update_gearbox(delta: float, throttle: float) -> void:
	speed_kmh = linear_velocity.length() * 3.6
	shift_timer = maxf(shift_timer - delta, 0.0)

	# Casi detenido: elegir reversa o 1ª según la tecla
	if speed_kmh < 3.0:
		if throttle < 0.0:
			current_gear = -1
		elif throttle > 0.0:
			current_gear = 1

	# Cambios automáticos (solo hacia adelante)
	if current_gear > 0 and shift_timer <= 0.0:
		var idx := current_gear - 1
		if current_gear < GEAR_MAX_SPEED.size() and throttle > 0.0 \
				and speed_kmh > GEAR_MAX_SPEED[idx] * UPSHIFT_AT:
			current_gear += 1
			shift_timer = SHIFT_TIME
		elif current_gear > 1 and speed_kmh < GEAR_MAX_SPEED[idx - 1] * DOWNSHIFT_AT:
			current_gear -= 1
			shift_timer = SHIFT_TIME

func _get_engine_force(throttle: float) -> float:
	if shift_timer > 0.0:
		return 0.0  # pausa mientras cambia

	if current_gear == -1:
		if throttle >= 0.0:
			return 0.0
		var rev_limit := clampf(inverse_lerp(REVERSE_MAX_SPEED * 1.05, REVERSE_MAX_SPEED, speed_kmh), 0.0, 1.0)
		return throttle * ENGINE_POWER * 0.6 * rev_limit

	if throttle <= 0.0:
		return 0.0
	var top := GEAR_MAX_SPEED[current_gear - 1]
	var limit := clampf(inverse_lerp(top * 1.05, top, speed_kmh), 0.0, 1.0)
	return throttle * ENGINE_POWER * GEAR_TORQUE[current_gear - 1] * limit

func get_gear_text() -> String:
	return "R" if current_gear == -1 else str(current_gear)

func _check_camera_switch():
	if linear_velocity.dot(transform.basis.z) > 0:
		camera_3d.current = true
	else:
		reverse_camera.current = true
