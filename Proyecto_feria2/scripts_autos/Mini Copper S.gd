extends VehicleBody3D

const MAX_STEER = 0.55        # Dirección más directa y rápida ("go-kart feel" del Mini)
const ENGINE_POWER = 9200.0   # Potencia equilibrada para el motor turbo del Cooper S

const GEAR_MAX_SPEED: Array[float] = [52.0, 90.0, 132.0, 172.0, 210.0]  # km/h máx. de 1ª a 5ª
const GEAR_TORQUE: Array[float] = [1.0, 0.76, 0.56, 0.43, 0.34]         # fuerza relativa por marcha
const REVERSE_MAX_SPEED := 32.0   # km/h máx. en reversa
const UPSHIFT_AT := 0.92          # sube al 92% de la vel. máx. de la marcha
const DOWNSHIFT_AT := 0.60        # baja al 60% de la vel. máx. de la marcha anterior
const SHIFT_TIME := 0.45          # tiempo de respuesta de cambio ágil
const BRAKE_POWER := 22.0         # frenado firme y deportivo

@onready var camera_pivot = $CameraPivot
@onready var camera_3d = $CameraPivot/Camera3D
@onready var reverse_camera = $CameraPivot/Camera3D2

var target_look_at: Vector3 = Vector3.ZERO
var current_gear := 1     # -1 = reversa, 1 a 5 = marchas
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

		steering = move_toward(steering, Input.get_axis("ui_right", "ui_left") * MAX_STEER, delta * 3.2)

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
		steering = move_toward(steering, 0.0, delta * 3.2)

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
	# Solo cambia a cámara de reversa si el auto retrocede de verdad (más de 1 m/s hacia atrás)
	if linear_velocity.dot(transform.basis.z) < -1.0:
		reverse_camera.current = true 
	else:
		camera_3d.current = true
		
# Devuelve un valor aproximado de RPM basado en la marcha y velocidad actual
func get_rpm() -> float:
	if current_gear == -1:
		return clamp((speed_kmh / REVERSE_MAX_SPEED) * 7000.0, 800.0, 7000.0)
	
	var max_speed_current_gear = GEAR_MAX_SPEED[current_gear - 1]
	var ratio = clamp(speed_kmh / max_speed_current_gear, 0.0, 1.0)
	
	return lerp(900.0, 6500.0, ratio)
