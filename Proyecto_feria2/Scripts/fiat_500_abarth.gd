extends VehicleBody3D

const MAX_STEER = 0.5
const ENGINE_POWER = 8500.0

const GEAR_MAX_SPEED: Array[float] = [50.0, 85.0, 125.0, 165.0, 200.0]  # km/h máx. de 1ª a 5ª
const GEAR_TORQUE: Array[float] = [1.0, 0.75, 0.55, 0.42, 0.33]         # fuerza relativa por marcha
const REVERSE_MAX_SPEED := 30.0   # km/h máx. en reversa
const UPSHIFT_AT := 0.92          # sube al 92% de la vel. máx. de la marcha
const DOWNSHIFT_AT := 0.60        # baja al 60% de la vel. máx. de la marcha anterior
const SHIFT_TIME := 0.5           # segundos sin tracción durante el cambio
const BRAKE_POWER := 20.0         # fuerza de freno

# --- Pasto ---
const TRACK_HALF_WIDTH := 7.0         # metros desde el centro de la trazada (Path3D) hasta el borde de la pista
const GRASS_EXIT_MARGIN := 1.0        # margen en metros para volver a "pista" (evita parpadeo en el borde)
const GRASS_SPEED_PENALTY := 30.0     # km/h que se restan a la velocidad con la que se entra al pasto
const GRASS_MIN_SPEED := 40.0         # tope mínimo sobre el pasto, para no quedar clavado si se entra despacio
const GRASS_DRAG := 0.3               # qué tan rápido frena al pasar el tope (m/s² por cada km/h de exceso)
const DEBUG_PASTO := true             # imprime un mensaje cada vez que entra/sale del pasto (poner en false al terminar)

@onready var camera_pivot = $Camera_Pivot
@onready var camera_3d = $Camera_Pivot/Camera3D
@onready var reverse_camera = $Camera_Pivot/Reverse_camera

var target_look_at: Vector3 = Vector3.ZERO
var current_gear := 1     # -1 = reversa, 1 a 5 = marchas
var speed_kmh := 0.0
var shift_timer := 0.0
var puede_conducir := false
var path: Path3D
var en_pasto := false
var grass_cap := INF      # velocidad máx. (km/h) mientras está en el pasto; INF = sin límite
@onready var meta: Area3D = $"../LineaMeta"

func _ready() -> void:
	add_to_group("jugador")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_look_at = global_position
	meta.carrera_terminada.connect(_on_carrera_terminada)
	path = get_node_or_null("../Path3D") as Path3D
	if path == null:
		push_warning("No se encontró ../Path3D: la penalización por pasto no va a funcionar")
	
	# Congela las físicas al iniciar para que no se deslice en la inclinación de la pista
	freeze = true

func _on_carrera_terminada() -> void:
	puede_conducir = false

func _physics_process(delta: float) -> void:
	_update_surface()
	_apply_grass_drag()

	if puede_conducir:
		# Si estaba congelado esperando el semáforo, lo liberamos al habilitar los controles
		if freeze:
			freeze = false

		steering = move_toward(steering, Input.get_axis("ui_right", "ui_left") * MAX_STEER, delta * 2.5)

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
		steering = move_toward(steering, 0.0, delta * 2.5)

	# Detectar si se presiona la letra R para enderezar el auto en cualquier momento
	if Input.is_key_pressed(KEY_R):
		_reset_orientation()

	camera_pivot.global_position = camera_pivot.global_position.lerp(global_position, delta * 20.0)
	camera_pivot.transform = camera_pivot.transform.interpolate_with(transform, delta * 5.0)

	target_look_at = target_look_at.lerp(global_position + linear_velocity, delta * 5.0)
	camera_3d.look_at(target_look_at)
	reverse_camera.look_at(target_look_at)

	_check_camera_switch()

# Detecta si el auto se salió de la pista midiendo su distancia a la trazada (Path3D).
# Al entrar al pasto fija un tope de velocidad: la velocidad de entrada menos GRASS_SPEED_PENALTY.
func _update_surface() -> void:
	if path == null or path.curve == null:
		return

	var closest_local := path.curve.get_closest_point(path.to_local(global_position))
	var closest := path.to_global(closest_local)
	# Distancia solo en el plano XZ, para ignorar desniveles
	var dist := Vector2(global_position.x - closest.x, global_position.z - closest.z).length()

	# Histéresis: entra al pasto al pasar el borde, y vuelve a "pista" un poco antes de ese borde
	var was_on_grass := en_pasto
	if en_pasto:
		en_pasto = dist > TRACK_HALF_WIDTH - GRASS_EXIT_MARGIN
	else:
		en_pasto = dist > TRACK_HALF_WIDTH

	if en_pasto and not was_on_grass:
		var entry_speed := linear_velocity.length() * 3.6
		grass_cap = maxf(entry_speed - GRASS_SPEED_PENALTY, GRASS_MIN_SPEED)
		if DEBUG_PASTO:
			print("Entró al pasto a %.0f km/h -> tope %.0f km/h" % [entry_speed, grass_cap])
	elif not en_pasto and was_on_grass:
		grass_cap = INF
		if DEBUG_PASTO:
			print("Volvió a la pista")

# Si el auto va más rápido que el tope del pasto, lo frena de forma gradual
func _apply_grass_drag() -> void:
	if not en_pasto:
		return
	var excess := linear_velocity.length() * 3.6 - grass_cap
	if excess > 0.0:
		apply_central_force(-linear_velocity.normalized() * mass * excess * GRASS_DRAG)

# Velocidad máxima (km/h) de una marcha
func _gear_top(gear: int) -> float:
	return REVERSE_MAX_SPEED if gear == -1 else GEAR_MAX_SPEED[gear - 1]

func _reset_orientation() -> void:
	# Guardamos la posición actual pero elevamos un poco el auto para que no colisione con el suelo
	var pos = global_position + Vector3(0, 1.5, 0)
	
	# Obtenemos la dirección hacia donde apunta el auto pero aplanada en el plano XZ
	var forward = -transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
		
	# Reseteamos las velocidades físicas para que no salga disparado
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Reubicamos el vehículo alineado correctamente de pie
	global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), pos)

func _update_gearbox(delta: float, throttle: float) -> void:
	speed_kmh = linear_velocity.length() * 3.6
	shift_timer = maxf(shift_timer - delta, 0.0)

	if speed_kmh < 3.0:
		if throttle < 0.0:
			current_gear = -1
		elif throttle > 0.0:
			current_gear = 1

	if current_gear > 0 and shift_timer <= 0.0:
		if current_gear < GEAR_MAX_SPEED.size() and throttle > 0.0 \
				and speed_kmh > _gear_top(current_gear) * UPSHIFT_AT:
			current_gear += 1
			shift_timer = SHIFT_TIME
		elif current_gear > 1 and speed_kmh < _gear_top(current_gear - 1) * DOWNSHIFT_AT:
			current_gear -= 1
			shift_timer = SHIFT_TIME

func _get_engine_force(throttle: float) -> float:
	if shift_timer > 0.0:
		return 0.0 

	if current_gear == -1:
		if throttle >= 0.0:
			return 0.0
		var rev_top := minf(_gear_top(-1), grass_cap)
		var rev_limit := clampf(inverse_lerp(rev_top * 1.05, rev_top, speed_kmh), 0.0, 1.0)
		return throttle * ENGINE_POWER * 0.6 * rev_limit

	if throttle <= 0.0:
		return 0.0
	# El motor se corta al llegar al tope de la marcha o al tope del pasto, lo que sea menor
	var top := minf(_gear_top(current_gear), grass_cap)
	var limit := clampf(inverse_lerp(top * 1.05, top, speed_kmh), 0.0, 1.0)
	return throttle * ENGINE_POWER * GEAR_TORQUE[current_gear - 1] * limit

func get_gear_text() -> String:
	return "R" if current_gear == -1 else str(current_gear)

func _check_camera_switch():
	if linear_velocity.dot(transform.basis.z) < -1.0:
		reverse_camera.current = true
	else:
		camera_3d.current = true
		
func get_rpm() -> float:
	var top := _gear_top(current_gear)
	if current_gear == -1:
		return clamp((speed_kmh / top) * 7000.0, 800.0, 7000.0)
	
	var ratio = clamp(speed_kmh / top, 0.0, 1.0)
	return lerp(900.0, 7000.0, ratio)
