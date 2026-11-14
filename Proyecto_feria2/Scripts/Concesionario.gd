
extends Control

# =========================================
# VEHÍCULOS
# =========================================

@export_group("Catálogo")

@export var vehicle_scenes: Array[PackedScene] = []
@export var vehicle_names: PackedStringArray = []
@export var vehicle_brands: PackedStringArray = []
@export var vehicle_specs: PackedStringArray = []
@export var vehicle_logos: Array[Texture2D] = []


# =========================================
# CONFIGURACIÓN DE ANIMACIONES
# =========================================

@export_group("Transiciones")

@export var fade_out_time: float = 0.20
@export var fade_in_time: float = 0.50
@export var slide_distance: float = 35.0


# =========================================
# REFERENCIAS
# =========================================

@onready var car_view: Control = $SubViewportContainer

@onready var car_holder: Node3D = $SubViewportContainer/SubViewport/CarHolder

@onready var info_panel: Control = $InfoPanel
@onready var brand_panel: Control = $BrandPanel

@onready var name_label: Label = $InfoPanel/NameLabel
@onready var specs_label: Label = $InfoPanel/SpecsLabel

@onready var brand_label: Label = $BrandPanel/BrandLabel
@onready var brand_logo: TextureRect = $BrandPanel/BrandLogo

@onready var previous_button: Button = $Anterior
@onready var next_button: Button = $Siguiente


# =========================================
# VARIABLES
# =========================================

var current_car: Node3D
var current_index: int = -1

var transition_tween: Tween
var transition_id: int = 0

var info_home_position: Vector2
var brand_home_position: Vector2


# =========================================
# INICIALIZACIÓN
# =========================================

func _ready() -> void:

	info_home_position = info_panel.position
	brand_home_position = brand_panel.position

	previous_button.pressed.connect(previous_vehicle)
	next_button.pressed.connect(next_vehicle)

	_hide_presentation()

	if vehicle_scenes.size() > 0:
		_display_vehicle(0)


# =========================================
# NAVEGACIÓN
# =========================================

func next_vehicle() -> void:

	if vehicle_scenes.is_empty():
		return

	_display_vehicle(current_index + 1)


func previous_vehicle() -> void:

	if vehicle_scenes.is_empty():
		return

	_display_vehicle(current_index - 1)


# =========================================
# CAMBIO DE VEHÍCULO
# =========================================

func _display_vehicle(index: int) -> void:

	if vehicle_scenes.is_empty():
		return

	current_index = wrapi(index, 0, vehicle_scenes.size())

	transition_id += 1
	var request_id := transition_id

	# Interrumpir animaciones anteriores.
	if transition_tween != null and transition_tween.is_running():
		transition_tween.kill()

	# Si ya hay un vehículo, ejecutar salida.
	if is_instance_valid(current_car):

		transition_tween = create_tween()

		transition_tween.set_parallel(true)
		transition_tween.set_trans(Tween.TRANS_CUBIC)
		transition_tween.set_ease(Tween.EASE_IN)

		transition_tween.tween_property(
			car_view, "modulate:a", 0.0, fade_out_time
		)

		transition_tween.tween_property(
			info_panel, "modulate:a", 0.0, fade_out_time
		)

		transition_tween.tween_property(
			brand_panel, "modulate:a", 0.0, fade_out_time
		)

		transition_tween.tween_property(
			info_panel,
			"position",
			info_home_position + Vector2(-slide_distance, 0),
			fade_out_time
		)

		transition_tween.tween_property(
			brand_panel,
			"position",
			brand_home_position + Vector2(slide_distance, 0),
			fade_out_time
		)

		transition_tween.chain().tween_callback(
			_install_vehicle.bind(current_index, request_id)
		)

	else:

		_install_vehicle(current_index, request_id)


# =========================================
# CARGAR VEHÍCULO
# =========================================

func _install_vehicle(index: int, request_id: int) -> void:

	if request_id != transition_id:
		return

	# Eliminar vehículo anterior.
	if is_instance_valid(current_car):

		car_holder.remove_child(current_car)
		current_car.queue_free()

		current_car = null

	# Crear vehículo nuevo.
	var instance: Node = vehicle_scenes[index].instantiate()

	if not instance is Node3D:
		push_error("El vehículo debe tener una raíz Node3D.")
		instance.queue_free()
		return

	current_car = instance as Node3D

	car_holder.add_child(current_car)

	# Actualizar información.
	name_label.text = vehicle_names[index] \
		if index < vehicle_names.size() else "Vehículo"

	brand_label.text = vehicle_brands[index] \
		if index < vehicle_brands.size() else ""

	specs_label.text = vehicle_specs[index] \
		if index < vehicle_specs.size() else ""

	brand_logo.texture = vehicle_logos[index] \
		if index < vehicle_logos.size() else null

	# Preparar presentación.
	_hide_presentation()

	# Animación de entrada.
	_play_intro()


# =========================================
# PREPARAR ELEMENTOS
# =========================================

func _hide_presentation() -> void:

	car_view.modulate.a = 0.0

	info_panel.modulate.a = 0.0
	brand_panel.modulate.a = 0.0

	info_panel.position = (
		info_home_position + Vector2(-slide_distance, 0)
	)

	brand_panel.position = (
		brand_home_position + Vector2(slide_distance, 0)
	)


# =========================================
# ANIMACIÓN DE ENTRADA
# =========================================

func _play_intro() -> void:

	transition_tween = create_tween()

	transition_tween.set_parallel(true)
	transition_tween.set_trans(Tween.TRANS_CUBIC)
	transition_tween.set_ease(Tween.EASE_OUT)

	# Aparición del vehículo.
	transition_tween.tween_property(
		car_view,
		"modulate:a",
		1.0,
		fade_in_time
	)

	# Entrada del panel informativo.
	transition_tween.tween_property(
		info_panel,
		"modulate:a",
		1.0,
		fade_in_time
	)

	transition_tween.tween_property(
		info_panel,
		"position",
		info_home_position,
		fade_in_time
	)

	# Entrada del logo.
	transition_tween.tween_property(
		brand_panel,
		"modulate:a",
		1.0,
		fade_in_time
	)

	transition_tween.tween_property(
		brand_panel,
		"position",
		brand_home_position,
		fade_in_time
	)
