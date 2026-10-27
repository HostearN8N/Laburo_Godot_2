extends VehicleBody3D

const MAX_STEER = 0.5
const ENGINE_POWER = 10500.0

const GEAR_MAX_SPEED: Array[float] = [50.0, 85.0, 125.0, 165.0, 200.0]  # km/h máx. de 1ª a 5ª
const GEAR_TORQUE: Array[float] = [1.0, 0.75, 0.55, 0.42, 0.33]         # fuerza relativa por marcha
const REVERSE_MAX_SPEED := 30.0   # km/h máx. en reversa
const UPSHIFT_AT := 0.92          # sube al 92% de la vel. máx. de la marcha
const DOWNSHIFT_AT := 0.60        # baja al 60% de la vel. máx. de la marcha anterior
const SHIFT_TIME := 0.5           # segundos sin tracción durante el cambio
const BRAKE_POWER := 20.0         


@export var path_follow: PathFollow3D  
@export var bot_speed: float = 18.0    

var current_gear := 1    
var speed_kmh := 0.0
var shift_timer := 0.0

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if not path_follow:
		return

	
	path_follow.progress += bot_speed * delta
	if path_follow.progress_ratio >= 1.0:
		path_follow.progress_ratio = 0.0

	
	var target_position = path_follow.global_position
	var local_target = to_local(target_position)
	var steering_val = atan2(-local_target.x, -local_target.z)
	
	
	steering = move_toward(steering, clamp(steering_val, -MAX_STEER, MAX_STEER), delta * 2.5)

	
	var steering_intensity = abs(steering)
	var throttle := 1.0
	
	if steering_intensity > 0.25:
		throttle = 0.4 
	if steering_intensity > 0.4:
		throttle = 0.0  

	
	_update_gearbox(delta, throttle)
	engine_force = _get_engine_force(throttle)

	
	var braking: bool = (steering_intensity > 0.35 and speed_kmh > 70.0) or (throttle == 0.0 and speed_kmh > 100.0)
	brake = BRAKE_POWER if braking else 0.0

func _update_gearbox(delta: float, throttle: float) -> void:
	speed_kmh = linear_velocity.length() * 3.6
	shift_timer = maxf(shift_timer - delta, 0.0)

	
	if speed_kmh < 3.0:
		current_gear = 1

	
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
		return 0.0  

	if throttle <= 0.0:
		return 0.0
		
	var top := GEAR_MAX_SPEED[current_gear - 1]
	var limit := clampf(inverse_lerp(top * 1.05, top, speed_kmh), 0.0, 1.0)
	return throttle * ENGINE_POWER * GEAR_TORQUE[current_gear - 1] * limit

func get_gear_text() -> String:
	return str(current_gear)
