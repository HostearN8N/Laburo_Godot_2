extends VehicleBody3D

const MAX_STEER = 0.48        # Dirección más pesada y estable a alta velocidad (típica de muscle car)
const ENGINE_POWER = 14800.0  # Torque masivo del V8 6.2L atmosférico

# Caja de 6 marchas con relaciones largas y velocidad punta alta
const GEAR_MAX_SPEED: Array[float] = [68.0, 112.0, 158.0, 205.0, 250.0, 285.0]
const GEAR_TORQUE: Array[float] = [1.0, 0.88, 0.76, 0.64, 0.52, 0.40] # Empuje muy fuerte en todas las marchas
const REVERSE_MAX_SPEED := 36.0   # km/h máx. en reversa
const UPSHIFT_AT := 0.92          # Cambia aprovechando el torque del V8 sin necesidad de pasarse de vueltas
const DOWNSHIFT_AT := 0.58        # Rebajes firmes para recuperar empuje
const SHIFT_TIME := 0.32          # Cambios con leve pausa mecánica clásica
const BRAKE_POWER := 32.0         # Frenos Brembo de serie (buena potencia para detener el peso del chasis)

@onready var camera_pivot = $CameraPivot
@onready var camera_3d = $CameraPivot/Camera3D2
@onready var reverse_camera = $CameraPivot/Camera3D

var target_look_at: Vector3 = Vector3.ZERO
var current_gear := 1     # -1 = reversa, 1 a 6 = marchas
var speed_kmh := 0.0
var shift_timer := 0.0
var puede_conducir := false
@onready var meta: Area3D = $"../LineaMeta"

func _ready() -> void:
	add_to_group("jugador")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_look_at = global_position
	meta.carrera_terminada.connect(_on_carrera_terminada)
	
	# Congela las físicas al iniciar para que no se deslice en la inclinación de la pista
	freeze = true

func _on_carrera_terminada() -> void:
	puede_conducir = false

func _physics_process(delta: float) -> void:
	if puede_conducir:
		# Si estaba congelado esperando el semáforo, lo liberamos al habilitar los controles
		if freeze:
			freeze = false

		steering = move_toward(steering, Input.get_axis("ui_right", "ui_left") * MAX_STEER, delta * 2.6)

		var throttle := Input.get_axis("ui_down", "ui_up")
		_update_gearbox(delta, throttle)
		engine_force = _get_engine_force(throttle)

		# Freno: se activa si la tecla va contra el sentido de marcha
		var braking := (current_gear > 0 and throttle < 0.0) or (current_gear == -1 and throttle > 0.0)
		brake = BRAKE_POWER if braking else 0.0
	else:
		# Esperando largada o carrera terminada: sin control, el auto frena y las ruedas se centran
		speed_kmh = linear_velocity.length() * 3.6
		engine_force = 0.0
		brake = BRAKE_POWER * 0.5
		steering = move_toward(steering, 0.0, delta * 2.6)

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
		return throttle * ENGINE_POWER * 0.5 * rev_limit

	if throttle <= 0.0:
		return 0.0
	var top := GEAR_MAX_SPEED[current_gear - 1]
	var limit := clampf(inverse_lerp(top * 1.
