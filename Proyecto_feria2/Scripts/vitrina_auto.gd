class_name VitrinaAuto
extends Node3D
## Muestra en un menu el auto que el jugador eligio en el concesionario.
##
## Uso: agregar un Node3D con este script dentro del SubViewport del menu
## (junto a la Camera3D) y ponerlo frente a la camara.
## Lee Global.auto_seleccionado_path (ruta de la escena jugable). Si no hay
## auto elegido, muestra default_scene_path.
##
## El auto se muestra "congelado": sin fisica, sin script de conduccion, sin
## camaras ni sonidos propios.


## Auto que se muestra si el jugador todavia no eligio ninguno.
@export_file("*.tscn") var default_scene_path: String = "res://Autos/fiat_500_abarth.tscn"

## Giro lento del auto en grados por segundo (0 = quieto).
@export var spin_speed_deg: float = 0.0

## Apoya cada auto en el piso automaticamente, sin importar donde tenga el
## origen su escena. El piso es la altura (Y) de este nodo Vitrina.
@export var align_to_ground: bool = true

## Ajuste de altura extra sobre el piso (positivo = sube).
@export var vertical_offset: float = 0.0

## Escala del auto en el menu.
@export var display_scale: float = 1.0

var current_car: Node3D


func _ready() -> void:
	show_selected_car()


func _process(delta: float) -> void:
	if spin_speed_deg != 0.0 and is_instance_valid(current_car):
		current_car.rotate_y(deg_to_rad(spin_speed_deg) * delta)


## Vuelve a leer la seleccion y reemplaza el auto mostrado.
func show_selected_car() -> void:

	var selected: Variant = Global.auto_seleccionado_path
	var path: String = "" if selected == null else str(selected)

	if path.is_empty() or not ResourceLoader.exists(path):
		path = default_scene_path

	var packed := load(path) as PackedScene

	if packed == null:
		push_warning("VitrinaAuto: no se pudo cargar '%s'." % path)
		return

	var instance: Node = packed.instantiate()
	var car := instance as Node3D

	if car == null:
		push_warning("VitrinaAuto: la raiz de '%s' no es un Node3D." % path)
		instance.free()
		return

	if is_instance_valid(current_car):
		current_car.queue_free()
		current_car = null

	_neutralize(car)

	car.scale = Vector3.ONE * display_scale
	add_child(car)
	car.position = Vector3.ZERO

	# Cada auto tiene su origen a una altura distinta: se apoya el punto mas
	# bajo (las ruedas) justo en el piso de la vitrina.
	if align_to_ground:
		car.position.y = -_get_lowest_point(car) * display_scale

	car.position.y += vertical_offset
	current_car = car


# Altura (en el espacio local del auto) del punto mas bajo de todas sus mallas.
func _get_lowest_point(car: Node3D) -> float:

	var lowest: float = INF
	var to_car: Transform3D = car.global_transform.affine_inverse()

	for node in car.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D

		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		var aabb: AABB = mesh_instance.mesh.get_aabb()
		var local_transform: Transform3D = to_car * mesh_instance.global_transform

		for i in range(8):
			var corner: Vector3 = local_transform * aabb.get_endpoint(i)
			lowest = minf(lowest, corner.y)

	if lowest == INF:
		return 0.0

	return lowest


# Deja el auto inerte: sin scripts, sin fisica, sin camaras ni audio.
func _neutralize(car: Node3D) -> void:

	# Se quitan los scripts ANTES de agregar el auto al arbol. Si no, el script
	# de conduccion corre su _ready() (busca LineaMeta, captura el mouse, etc.)
	# y da errores en el menu.
	car.set_script(null)

	for node in car.find_children("*", "Node", true, false):
		if node.get_script() != null:
			node.set_script(null)

	for node in car.find_children("*", "Camera3D", true, false):
		node.get_parent().remove_child(node)
		node.free()

	for node in car.find_children("*", "AudioStreamPlayer3D", true, false):
		node.get_parent().remove_child(node)
		node.free()

	var body := car as RigidBody3D

	if body != null:
		body.freeze = true

	car.process_mode = Node.PROCESS_MODE_DISABLED
