
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

# Ajuste individual de altura para cada vehículo.
# Positivo = sube el auto.
# Negativo = baja el auto.
# Cero = posición original.

@export var vehicle_vertical_offsets: Array[float] = []


# =========================================
# CONFIGURACIÓN DE TRANSICIONES
# =========================================

@export_group("Transiciones")

@export var fade_out_time: float = 0.20
@export var fade_in_time: float = 0.50
@export var slide_distance: float = 35.0


# =========================================
# ANIMACIÓN DE FLECHAS
# =========================================

@export_group("Animación de flechas")

@export var arrow_lift_distance: float = 8.0
@export var arrow_animation_duration: float = 0.12

var previous_home_position: Vector2
var next_home_position: Vector2

var button_tweens: Dictionary = {}


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
	previous_button.focus_mode = Control.FOCUS_NONE
	next_button.focus_mode = Control.FOCUS_NONE
	info_home_position = info_panel.position
	brand_home_position = brand_panel.position

	# Guardar posiciones originales de las flechas.
	previous_home_position = previous_button.position
	next_home_position = next_button.position

	# Conectar navegación.
	previous_button.pressed.connect(previous_vehicle)
	next_button.pressed.connect(next_vehicle)

	# Conectar animaciones de las flechas.
	previous_button.button_down.connect(
		_on_arrow_button_down.bind(previous_button)
	)

	previous_button.button_up.connect(
		_on_arrow_button_up.bind(previous_button)
	)

	next_button.button_down.connect(
		_on_arrow_button_down.bind(next_button)
	)

	next_button.button_up.connect(
		_on_arrow_button_up.bind(next_button)
	)

	# Preparar presentación.
	_hide_presentation()

	var valid_indices := _get_valid_vehicle_indices()

	# Las flechas solamente se deshabilitan si no hay autos.
	previous_button.disabled = valid_indices.is_empty()
	next_button.disabled = valid_indices.is_empty()

	if not valid_indices.is_empty():
		_display_vehicle(valid_indices[0])


# =========================================
# DETECTAR VEHÍCULOS DISPONIBLES
# =========================================

func _get_valid_vehicle_indices() -> Array[int]:

	var valid_indices: Array[int] = []

	for i in range(vehicle_scenes.size()):

		if vehicle_scenes[i] != null:
			valid_indices.append(i)

	return valid_indices


# =========================================
# NAVEGACIÓN
# =========================================

func next_vehicle() -> void:

	_cycle_vehicle(1)


func previous_vehicle() -> void:

	_cycle_vehicle(-1)


func _cycle_vehicle(direction: int) -> void:

	var valid_indices := _get_valid_vehicle_indices()

	if valid_indices.size() <= 1:
		return

	var position := valid_indices.find(current_index)

	if position == -1:
		position = 0

	position = posmod(
		position + direction,
		valid_indices.size()
	)

	_display_vehicle(valid_indices[position])


# =========================================
# CAMBIO DE VEHÍCULO
# =========================================

func _display_vehicle(index: int) -> void:

	if index < 0 or index >= vehicle_scenes.size():
		return

	if vehicle_scenes[index] == null:
		return

	current_index = index

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
			car_view,
			"modulate:a",
			0.0,
			fade_out_time
		)

		transition_tween.tween_property(
			info_panel,
			"modulate:a",
			0.0,
			fade_out_time
		)

		transition_tween.tween_property(
			brand_panel,
			"modulate:a",
			0.0,
			fade_out_time
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
			_install_vehicle.bind(index, request_id)
		)

	else:

		_install_vehicle(index, request_id)


# =========================================
# CARGAR VEHÍCULO
# =========================================

func _install_vehicle(index: int, request_id: int) -> void:

	if request_id != transition_id:
		return

	if index < 0 or index >= vehicle_scenes.size():
		return

	if vehicle_scenes[index] == null:
		return

	# Eliminar vehículo anterior.
	if is_instance_valid(current_car):

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

	# =====================================
	# AJUSTE INDIVIDUAL DE ALTURA
	# =====================================

	if index < vehicle_vertical_offsets.size():

		current_car.position.y += vehicle_vertical_offsets[index]

	# =====================================
	# ACTUALIZAR INFORMACIÓN
	# =====================================

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


# =========================================
# ANIMACIÓN DE FLECHAS
# =========================================

func _on_arrow_button_down(button: Button) -> void:

	_animate_arrow(button, true)


func _on_arrow_button_up(button: Button) -> void:

	_animate_arrow(button, false)


func _animate_arrow(button: Button, lifted: bool) -> void:

	# Interrumpir animación anterior de esta flecha.
	if button_tweens.has(button):

		var old_tween: Tween = button_tweens[button]

		if old_tween.is_running():
			old_tween.kill()

	# Obtener posición original.
	var home_position: Vector2

	if button == previous_button:
		home_position = previous_home_position
	else:
		home_position = next_home_position

	# Calcular posición de destino.
	var target_position := home_position

	if lifted:
		target_position.y -= arrow_lift_distance

	# Crear animación.
	var tween := create_tween()

	button_tweens[button] = tween

	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		button,
		"position",
		target_position,
		arrow_animation_duration
	)
# Arreglo con las rutas exactas de las escenas jugables (.tscn) de cada auto en el mismo orden del carrusel
var rutas_autos: Array[String] = [
	"res://Autos/fiat_500_abarth.tscn",
	"res://escenas_autos/Mini Cooper S.tscn",
	"res://escenas_autos/Ford Fiesta ST.tscn",
	"res://escenas_autos/Bmw 128i.tscn",
	"res://Autos/golf gti.tscn",
]

# =========================================
# SELECCIÓN DE AUTO (ENTER)
# =========================================

var rutas_autos_jugables: Array[String] = [
	"res://Autos/fiat_500_abarth.tscn", # <-- Verifica el nombre exacto de tu Fiat 500 en esa carpeta
	"res://escenas_autos/Mini Cooper S.tscn",
	"res://escenas_autos/Ford Fiesta ST.tscn",       # <-- Verifica el nombre exacto en esa carpeta
	"res://escenas_autos/Bmw 128i.tscn",
	"res://Autos/golf gti.tscn",
]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			seleccionar_auto_actual()
			get_viewport().set_input_as_handled()


func seleccionar_auto_actual() -> void:
	if current_index < 0 or current_index >= rutas_autos_jugables.size():
		push_warning("No hay una ruta jugable configurada para el índice: ", current_index)
		return
	
	Global.auto_seleccionado_path = rutas_autos_jugables[current_index]
	print("Auto guardado con Enter: ", Global.auto_seleccionado_path)
	
	# Descomenta y pon la ruta de tu menú/garaje si quieres volver automáticamente:
	# get_tree().change_scene_to_file("res://escenas/menu_principal.tscn")
