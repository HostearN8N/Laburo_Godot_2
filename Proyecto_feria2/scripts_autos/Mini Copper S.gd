extends VehicleBody3D

const MAX_STEER = 0.47
const ENGINE_POWER = 8750.0

const GEAR_MAX_SPEED: Array[float] = [58.0, 98.0, 140.0, 178.0, 210.0, 232.0]  # km/h máx. de 1ª a 6ª
const GEAR_TORQUE: Array[float] = [1.08, 0.85, 0.67, 0.53, 0.43, 0.36]         # entrega más lineal y elástica
const REVERSE_MAX_SPEED := 38.0   # km/h máx. en reversa
const UPSHIFT_AT := 0.94          # estira un poco más las marchas antes de pasar
const DOWNSHIFT_AT := 0.62        # baja al 62% de la vel. máx. de la marcha anterior
const SHIFT_TIME := 0.26          # cambios ligeramente más rápidos y secos
const BRAKE_POWER := 35.0         # frenada muy directa y firme

# --- Pasto ---
const TRACK_HALF_WIDTH := 7.0         # metros desde el centro de la trazada (Path3D) hasta el borde de la pista
const GRASS_EXIT_MARGIN := 1.0        # margen en metros para volver a "pista" (evita parpadeo en el borde)
const GRASS_SPEED_PENALTY := 30.0     # km/h que se restan a la velocidad con la que se entra al pasto
const GRASS_MIN_SPEED := 40.0         # tope mínimo sobre el pasto, para no quedar clavado si se entra despacio
const GRASS_DRAG := 0.3               # qué tan rápido frena al pasar el tope (m/s² por cada km/h de exceso)
const DEBUG_PASTO := true             # imprime un mensaje cada vez que entra/sale del pasto (poner en false al terminar)

# --- Contramano ---
const PATH_REVERSED := false          # poner en true si el Path3D está dibujado al revés del sentido de carrera
const WRONG_WAY_MAX_SPEED := 10.0     # km/h máx. permitidos a contramano (lo justo para maniobrar y dar la vuelta)
const WRONG_WAY_MIN_SPEED := 5.0      # por debajo de esta velocidad no se considera contramano
const WRONG_WAY_ANGLE_COS := 0.4      # cuánto debe ir en contra de la pista (0.4 = más de ~114° respecto al sentido correcto)
const WRONG_WAY_DETECT_TIME := 0.5    # segundos yendo en contra antes de activar el bloqueo
const WRONG_WAY_REALIGN_TIME := 3.0   # segundos a contramano antes de girar el auto solo (poner 999 para desactivar)
const WRONG_WAY_DRAG := 0.5           # qué tan fuerte frena al pasar el tope de contramano
const WRONG_WAY_MAX_DIST := 25.0      # a más de estos metros de la trazada no se evalúa el sentido
const TANGENT_STEP := 3.0             # metros hacia adelante/atrás para calcular el sentido de la pista
const MAX_LIMIT_DECEL := 15.0         # desaceleración máx. (m/s²) que pueden aplicar el pasto y el contramano
const WRONG_WAY_START_GRACE := 5.0    # segundos desde la largada en los que no se evalúa el contramano
const WRONG_WAY_NOSE_COS := 0.3       # el auto debe ir de trompa (no de culata) para contar como contramano
const NOSE_IS_PLUS_Z := true          # este auto avanza hacia +Z (por eso la cámara de reversa usa basis.z); si al reubicarse queda mirando al revés, poner en false
const DEBUG_CONTRAMANO := true        # imprime los datos cada vez que se activa el contramano (poner en false al terminar)

@onready var camera_pivot = $Camera_Pivot
@onready var camera_3d = $Camera_Pivot/camera3D
@onready var reverse_camera = $Camera_Pivot/reverse_camera

var current_gear := 1     # -1 = reversa, 1 a 6 = marchas
var speed_kmh := 0.0
var shift_timer := 0.0
var puede_conducir := false
var path: Path3D
var en_pasto := false
var grass_cap := INF      # velocidad máx. (km/h) mientras está en el pasto; INF = sin límite
var track_dir := Vector3.ZERO   # sentido de la pista en el punto más cercano (plano XZ, normalizado)
var contramano := false
var wrong_way_time := 0.0
var wrong_way_cap := INF  # velocidad máx. (km/h) mientras va a contramano; INF = sin límite
var wrong_way_label: Label
var race_time := 0.0      # segundos desde que se habilitó el control (largada)
var _dbg_offset := 0.0
var _dbg_dist := 0.0
@onready var meta: Area3D = $"../LineaMeta"

func _ready() -> void:
	add_to_group("jugador")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	meta.carrera_terminada.connect(_on_carrera_terminada)
	path = get_node_or_null("../Path3D") as Path3D
	if path == null:
		push_warning("No se encontró ../Path3D: el pasto y el contramano no van a funcionar")
	_create_wrong_way_label()
	
	# Congela las físicas al iniciar para que no se deslice en la inclinación de la pista
	freeze = true

func _on_carrera_terminada() -> void:
	puede_conducir = false

# Crea el cartel de "contramano" por código, así no hace falta tocar el HUD
func _create_wrong_way_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	wrong_way_label = Label.new()
	wrong_way_label.text = "¡CONTRAMANO!"
	wrong_way_label.add_theme_font_size_override("font_size", 56)
	wrong_way_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.1))
	wrong_way_label.add_theme_color_override("font_outline_color", Color.BLACK)
	wrong_way_label.add_theme_constant_override("outline_size", 10)
	wrong_way_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_way_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wrong_way_label.offset_top = 120.0
	wrong_way_label.offset_bottom = 200.0
	wrong_way_label.visible = false
	layer.add_child(wrong_way_label)

func _physics_process(delta: float) -> void:
	_update_surface()
	_update_wrong_way(delta)
	_apply_speed_limit_drag()

	if puede_conducir:
		# Si estaba congelado esperando el semáforo, lo liberamos al habilitar los controles
		if freeze:
			freeze = false

		# Dirección progresiva: ágil en curvas cerradas y estable a más de 200 km/h
		var speed_factor := clampf(speed_kmh / GEAR_MAX_SPEED[-1], 0.0, 1.0)
		var dynamic_steer := lerpf(MAX_STEER, MAX_STEER * 0.44, speed_factor)
		var steer_speed := lerpf(3.2, 1.9, speed_factor)
		steering = move_toward(steering, Input.get_axis("ui_right", "ui_left") * dynamic_steer, delta * steer_speed)

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
		steering = move_toward(steering, 0.0, delta * 3.0)

	# Detectar si se presiona la letra R para enderezar el auto en cualquier momento
	if Input.is_key_pressed(KEY_R):
		_reset_orientation()

	# Sigue suavemente la posición y rotación del auto sin forzar el ángulo de las cámaras
	camera_pivot.global_position = camera_pivot.global_position.lerp(global_position, delta * 20.0)
	camera_pivot.global_rotation.y = lerp_angle(camera_pivot.global_rotation.y, global_rotation.y, delta * 6.0)

	_check_camera_switch()

# Mide la posición del auto respecto a la trazada (Path3D) para saber:
#  - si se salió de la pista (pasto) y fijar el tope de velocidad
#  - hacia dónde va la pista en ese punto (para detectar el contramano)
func _update_surface() -> void:
	track_dir = Vector3.ZERO
	if path == null or path.curve == null or path.curve.point_count < 2:
		return

	var curve := path.curve
	var offset := curve.get_closest_offset(path.to_local(global_position))
	var closest := path.to_global(curve.sample_baked(offset))
	# Distancia solo en el plano XZ, para ignorar desniveles
	var dist := Vector2(global_position.x - closest.x, global_position.z - closest.z).length()
	_dbg_offset = offset
	_dbg_dist = dist

	# --- Sentido de la pista (tangente de la trazada en este punto) ---
	var length := curve.get_baked_length()
	var p_ahead := path.to_global(curve.sample_baked(minf(offset + TANGENT_STEP, length)))
	var p_behind := path.to_global(curve.sample_baked(maxf(offset - TANGENT_STEP, 0.0)))
	var dir := p_ahead - p_behind
	dir.y = 0.0
	if dir.length() > 0.01 and dist < WRONG_WAY_MAX_DIST:
		track_dir = dir.normalized() * (-1.0 if PATH_REVERSED else 1.0)

	# --- Pasto ---
	# Histéresis: entra al pasto al pasar el borde, y vuelve a "pista" un poco antes de ese borde
	var was_on_grass := en_pasto
	if en_pasto:
		en_pasto = dist > TRACK_HALF_WIDTH - GRASS_EXIT_MARGIN
	else:
		en_pasto = dist > TRACK_HALF_WIDTH

	# Al entrar al pasto el tope es la velocidad de entrada menos GRASS_SPEED_PENALTY
	if en_pasto and not was_on_grass:
		var entry_speed := linear_velocity.length() * 3.6
		grass_cap = maxf(entry_speed - GRASS_SPEED_PENALTY, GRASS_MIN_SPEED)
		if DEBUG_PASTO:
			print("Entró al pasto a %.0f km/h -> tope %.0f km/h" % [entry_speed, grass_cap])
	elif not en_pasto and was_on_grass:
		grass_cap = INF
		if DEBUG_PASTO:
			print("Volvió a la pista")

# Detecta si el auto avanza en contra del sentido de la pista.
# A contramano la velocidad queda limitada; si sigue así unos segundos, el auto se gira solo.
func _update_wrong_way(delta: float) -> void:
	# Segundos desde que se habilitó el control (largada)
	if puede_conducir:
		race_time += delta
	else:
		race_time = 0.0

	var vel := linear_velocity
	vel.y = 0.0
	var vel_kmh := vel.length() * 3.6

	var going_wrong := false
	# Contramano = avanzar de trompa en contra del sentido de la pista.
	# No cuenta ir de culata (por ejemplo, deslizarse hacia atrás por la pendiente de la largada)
	# ni los primeros segundos de la carrera.
	if puede_conducir and race_time > WRONG_WAY_START_GRACE \
			and track_dir != Vector3.ZERO and vel_kmh > WRONG_WAY_MIN_SPEED:
		var vel_dir := vel.normalized()
		var nose := transform.basis.z if NOSE_IS_PLUS_Z else -transform.basis.z
		nose.y = 0.0
		if nose.length() > 0.01:
			var nose_first := vel_dir.dot(nose.normalized()) > WRONG_WAY_NOSE_COS
			going_wrong = nose_first and vel_dir.dot(track_dir) < -WRONG_WAY_ANGLE_COS

	if going_wrong:
		wrong_way_time += delta
	else:
		wrong_way_time = maxf(wrong_way_time - delta * 4.0, 0.0)

	var was_wrong := contramano
	contramano = wrong_way_time >= WRONG_WAY_DETECT_TIME
	if DEBUG_CONTRAMANO and contramano and not was_wrong:
		print("CONTRAMANO | offset %.0f | dist %.1f m | vel %.0f km/h | track_dir %s | pos %s" % [_dbg_offset, _dbg_dist, vel_kmh, track_dir, global_position])
	wrong_way_cap = WRONG_WAY_MAX_SPEED if contramano else INF
	wrong_way_label.visible = contramano

	# Demasiado tiempo a contramano: se reubica el auto mirando hacia el sentido correcto
	if wrong_way_time >= WRONG_WAY_REALIGN_TIME:
		_reset_orientation(track_dir)
		wrong_way_time = 0.0

# Si el auto va más rápido que el tope (pasto o contramano), lo frena de forma gradual
func _apply_speed_limit_drag() -> void:
	var speed := linear_velocity.length() * 3.6
	var decel := maxf((speed - grass_cap) * GRASS_DRAG, (speed - wrong_way_cap) * WRONG_WAY_DRAG)
	if decel > 0.0:
		decel = minf(decel, MAX_LIMIT_DECEL)
		apply_central_force(-linear_velocity.normalized() * mass * decel)

# Velocidad máxima (km/h) de una marcha
func _gear_top(gear: int) -> float:
	return REVERSE_MAX_SPEED if gear == -1 else GEAR_MAX_SPEED[gear - 1]

# Endereza el auto. Si se pasa nose_dir, deja la TROMPA del auto mirando hacia esa dirección;
# si no, conserva hacia donde apuntaba.
func _reset_orientation(nose_dir := Vector3.ZERO) -> void:
	var pos = global_position + Vector3(0, 1.5, 0)
	
	var look := -transform.basis.z
	if nose_dir != Vector3.ZERO:
		look = -nose_dir if NOSE_IS_PLUS_Z else nose_dir
	look.y = 0.0
	look = look.normalized()
	if look.length_squared() < 0.01:
		look = Vector3.FORWARD
		
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	global_transform = Transform3D(Basis.looking_at(look, Vector3.UP), pos)

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

	var cap := minf(grass_cap, wrong_way_cap)

	if current_gear == -1:
		if throttle >= 0.0:
			return 0.0
		var rev_top := minf(_gear_top(-1), cap)
		var rev_limit := clampf(inverse_lerp(rev_top * 1.05, rev_top, speed_kmh), 0.0, 1.0)
		return throttle * ENGINE_POWER * 0.65 * rev_limit

	if throttle <= 0.0:
		return 0.0
	var top := minf(_gear_top(current_gear), cap)
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
