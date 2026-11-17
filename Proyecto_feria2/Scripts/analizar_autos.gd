@tool
extends EditorScript
## Herramienta del editor (no es parte del juego).
##
## Lee las escenas de bot de todos los autos, las compara con el Fiat 500
## Abarth (la referencia) y escribe en la Salida:
##   - masa, centro de masa, ancho de via, batalla y estabilidad de cada auto
##   - los valores actuales del bot de cada auto
##   - valores SUGERIDOS de partida para corner_speed, max_speed y frenos,
##     escalados a partir del Fiat
##
## Como usarla: abrir este archivo en el editor de scripts y ejecutar
## Archivo > Ejecutar (Ctrl+Mayus+X). No modifica ninguna escena.
##
## Estabilidad (SSF) = ancho de via / (2 * altura del centro de masa).
## Cuanto mas baja, mas facil vuelca el auto. El factor de ajuste es la raiz
## del cociente entre el SSF del auto y el del Fiat, porque la aceleracion
## lateral aguantada sin volcar es proporcional al SSF y la velocidad en
## curva crece con la raiz de la aceleracion lateral.


const REFERENCE_PATH: String = "res://Autos/fiat_500_abarth_bot.tscn"

const BOT_SCENES: Array[String] = [
	"res://Autos/fiat_500_abarth_bot.tscn",
	"res://Autos/Mini_Cooper_S_bot.tscn",
	"res://Autos/Ford_Fiesta_bot.tscn",
	"res://Autos/Bmw_128i_bot.tscn",
	"res://Autos/Golf_gti_bot.tscn",
]

## Valores del script del bot que se leen de cada escena.
const BOT_PROPERTIES: Array[StringName] = [
	&"engine_power",
	&"brake_power",
	&"max_speed",
	&"corner_speed",
	&"obstacle_brake_power",
	&"wheelbase",
	&"max_steer",
	&"lookahead_distance",
	&"steering_response",
	&"launch_speed_cap",
	&"launch_power_scale",
]

## Limites del factor de ajuste (1.0 = igual que el Fiat).
const MIN_STABILITY_FACTOR: float = 0.5


func _run() -> void:

	print("")
	print("===== ANALISIS DE AUTOS =====")

	var reference: Dictionary = _analyze(REFERENCE_PATH)

	if reference.is_empty():
		print("No se pudo analizar la referencia: ", REFERENCE_PATH)
		return

	for path in BOT_SCENES:

		var info: Dictionary = reference

		if path != REFERENCE_PATH:
			info = _analyze(path)

		if info.is_empty():
			continue

		_print_info(info)

		if path != REFERENCE_PATH:
			_print_suggestion(info, reference)

	print("")
	print("===== FIN =====")


func _analyze(path: String) -> Dictionary:

	var packed := load(path) as PackedScene

	if packed == null:
		print("No se pudo cargar: ", path)
		return {}

	var instance: Node = packed.instantiate()
	var car := instance as VehicleBody3D

	if car == null:
		print("La raiz no es un VehicleBody3D: ", path)
		instance.free()
		return {}

	var info: Dictionary = {}
	info["name"] = path.get_file()
	info["mass"] = car.mass
	info["com_custom"] = car.center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	info["com"] = car.center_of_mass

	# Valores del script del bot (null si la escena no tiene el script del bot).
	var bot: Dictionary = {}

	for property_name in BOT_PROPERTIES:
		bot[property_name] = car.get(property_name)

	info["bot"] = bot

	# Ruedas.
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	var contact_sum: float = 0.0
	var wheel_count: int = 0
	var wheel_lines: Array[String] = []

	for node in car.find_children("*", "VehicleWheel3D", true, false):
		var wheel := node as VehicleWheel3D

		if wheel == null:
			continue

		wheel_count += 1

		min_x = minf(min_x, wheel.position.x)
		max_x = maxf(max_x, wheel.position.x)
		min_z = minf(min_z, wheel.position.z)
		max_z = maxf(max_z, wheel.position.z)

		contact_sum += wheel.position.y - wheel.wheel_rest_length - wheel.wheel_radius

		wheel_lines.append(
			"  %s pos=(%.2f, %.2f, %.2f) radio=%.2f largo_reposo=%.2f roll_influence=%.2f friccion=%.1f susp_rigidez=%.1f susp_recorrido=%.2f susp_fuerza_max=%.0f amort_comp=%.2f amort_relaj=%.2f tracc=%s direc=%s" % [
				wheel.name,
				wheel.position.x, wheel.position.y, wheel.position.z,
				wheel.wheel_radius,
				wheel.wheel_rest_length,
				wheel.wheel_roll_influence,
				wheel.wheel_friction_slip,
				wheel.suspension_stiffness,
				wheel.suspension_travel,
				wheel.suspension_max_force,
				wheel.damping_compression,
				wheel.damping_relaxation,
				str(wheel.use_as_traction),
				str(wheel.use_as_steering)
			]
		)

	info["wheel_lines"] = wheel_lines

	# Formas de colision (para estimar la altura del centro de masa).
	var shape_center_sum: float = 0.0
	var shape_count: int = 0
	var shape_lines: Array[String] = []

	for node in car.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D

		if collision == null or collision.shape == null:
			continue

		var debug_mesh: Mesh = collision.shape.get_debug_mesh()
		var aabb: AABB = debug_mesh.get_aabb()
		var center_y: float = collision.position.y + aabb.get_center().y * collision.scale.y

		shape_center_sum += center_y
		shape_count += 1

		shape_lines.append(
			"  %s pos_y=%.2f centro_y=%.2f alto=%.2f ancho=%.2f largo=%.2f" % [
				collision.name,
				collision.position.y,
				center_y,
				aabb.size.y * collision.scale.y,
				aabb.size.x * collision.scale.x,
				aabb.size.z * collision.scale.z
			]
		)

	info["shape_lines"] = shape_lines

	# Estabilidad.
	var track_width: float = 0.0
	var wheelbase: float = 0.0
	var com_height: float = 0.0
	var ssf: float = 0.0

	if wheel_count > 0:
		track_width = max_x - min_x
		wheelbase = max_z - min_z

		var contact_y: float = contact_sum / float(wheel_count)
		var com_y: float = 0.0
		var com_known: bool = false

		if bool(info["com_custom"]):
			com_y = car.center_of_mass.y
			com_known = true
		elif shape_count > 0:
			com_y = shape_center_sum / float(shape_count)
			com_known = true

		if com_known:
			com_height = com_y - contact_y

			if com_height > 0.05:
				ssf = track_width / (2.0 * com_height)

	info["track_width"] = track_width
	info["wheelbase"] = wheelbase
	info["com_height"] = com_height
	info["ssf"] = ssf

	car.free()

	return info


func _print_info(info: Dictionary) -> void:

	print("")
	print("--- ", info["name"], " ---")

	print(
		"masa=%.0f | centro de masa %s: %s | ancho de via=%.2f | batalla=%.2f | altura del centro de masa=%.2f | SSF=%.2f" % [
			float(info["mass"]),
			"personalizado" if bool(info["com_custom"]) else "automatico (estimado con las colisiones)",
			str(info["com"]),
			float(info["track_width"]),
			float(info["wheelbase"]),
			float(info["com_height"]),
			float(info["ssf"])
		]
	)

	print("valores del bot: ", info["bot"])

	print("ruedas:")
	for line in info["wheel_lines"]:
		print(line)

	print("colisiones:")
	for line in info["shape_lines"]:
		print(line)


func _bot_value(info: Dictionary, property_name: StringName) -> float:

	var bot: Dictionary = info["bot"]
	var value: Variant = bot.get(property_name)

	if value == null:
		return -1.0

	return float(value)


func _print_suggestion(info: Dictionary, reference: Dictionary) -> void:

	var ssf: float = float(info["ssf"])
	var reference_ssf: float = float(reference["ssf"])
	var reference_mass: float = float(reference["mass"])
	var mass: float = float(info["mass"])

	if ssf <= 0.0 or reference_ssf <= 0.0 or reference_mass <= 0.0:
		print("SUGERENCIA: faltan datos (ruedas o colisiones) para calcularla.")
		return

	var reference_corner: float = _bot_value(reference, &"corner_speed")
	var reference_max: float = _bot_value(reference, &"max_speed")
	var reference_brake: float = _bot_value(reference, &"brake_power")
	var reference_obstacle_brake: float = _bot_value(reference, &"obstacle_brake_power")

	if reference_corner < 0.0 or reference_max < 0.0 or reference_brake < 0.0:
		print("SUGERENCIA: el Fiat no tiene el script del bot.")
		return

	var stability_factor: float = clampf(
		sqrt(ssf / reference_ssf),
		MIN_STABILITY_FACTOR,
		1.0
	)

	var mass_ratio: float = mass / reference_mass

	print("")
	print(
		"SUGERENCIA para %s (punto de partida, tomando como base al Fiat):" % info["name"]
	)
	print("  factor de estabilidad = %.2f | relacion de masa = %.2f" % [stability_factor, mass_ratio])
	print("  corner_speed = %.0f   (Fiat: %.0f)" % [reference_corner * stability_factor, reference_corner])
	print("  max_speed = %.0f   (Fiat: %.0f)" % [reference_max * stability_factor, reference_max])
	print("  brake_power = %.1f   (Fiat: %.1f)" % [reference_brake * mass_ratio, reference_brake])

	if reference_obstacle_brake >= 0.0:
		print(
			"  obstacle_brake_power = %.1f   (Fiat: %.1f)" % [
				reference_obstacle_brake * mass_ratio,
				reference_obstacle_brake
			]
		)
