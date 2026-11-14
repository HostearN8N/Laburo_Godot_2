extends CanvasLayer

@onready var label_timer: Label = $Control/PanelContainer_Timer/MarginContainer/LabelTimer
@onready var label_speed: Label = $Control/PanelContainer_Speed/VBoxContainer/LabelSpeed
@onready var label_gear: Label = $Control/PanelContainer_Speed/VBoxContainer/LabelGear
@onready var progress_bar_rpm: ProgressBar = $Control/PanelContainer_Speed/VBoxContainer/ProgressBarspeed
@onready var texture_semaforo: TextureRect = $Control/TextureSemaforo

@export var vehicle_path: NodePath
var vehicle: Node3D = null

# --- IMÁGENES DEL SEMÁFORO ---
@export var imagen_paso_1: Texture2D
@export var imagen_paso_2: Texture2D
@export var imagen_paso_3: Texture2D
@export var imagen_verde: Texture2D

# --- CRONÓMETRO ---
var time_elapsed: float = 0.0
var is_timer_running: bool = false

# --- CUENTA REGRESIVA (20 segundos en total, 5 por imagen) ---
var countdown_time: float = 4.0
var race_started: bool = false

# --- TACÓMETRO (RPM) ---
@export var max_rpm: float = 7000.0
var rpm_fill_style: StyleBoxFlat

func _ready() -> void:
	if vehicle_path:
		vehicle = get_node_or_null(vehicle_path)
	
	# Configurar barra de RPM
	if progress_bar_rpm:
		progress_bar_rpm.min_value = 0
		progress_bar_rpm.max_value = max_rpm
		progress_bar_rpm.show_percentage = false
		
		rpm_fill_style = StyleBoxFlat.new()
		rpm_fill_style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
		rpm_fill_style.corner_radius_top_left = 4
		rpm_fill_style.corner_radius_top_right = 4
		rpm_fill_style.corner_radius_bottom_left = 4
		rpm_fill_style.corner_radius_bottom_right = 4
		progress_bar_rpm.add_theme_stylebox_override("fill", rpm_fill_style)

	# Mostrar la primera imagen del semáforo apenas carga la carrera
	if texture_semaforo and imagen_paso_1:
		texture_semaforo.visible = true
		texture_semaforo.texture = imagen_paso_1

func _process(delta: float) -> void:
	# Mientras no haya largado la carrera, corre el semáforo y los autos están congelados
	if not race_started:
		_update_countdown(delta)
		return

	# Una vez que larga, corre el cronómetro y se actualiza la telemetría del auto
	_update_timer(delta)
	_update_vehicle_hud()

func _update_countdown(delta: float) -> void:
	countdown_time -= delta
	
	if texture_semaforo:
		if countdown_time > 3.0:
			texture_semaforo.texture = imagen_paso_1
		elif countdown_time > 2.0:
			texture_semaforo.texture = imagen_paso_2
		elif countdown_time > 1.0:
			texture_semaforo.texture = imagen_paso_3
		elif countdown_time > 0.0:
			texture_semaforo.texture = imagen_verde
		else:
			# ¡Terminó la cuenta regresiva! Desbloqueamos autos, arranca el reloj y ocultamos el semáforo
			race_started = true
			is_timer_running = true
			_liberar_autos()
			texture_semaforo.visible = false

func _liberar_autos() -> void:
	get_tree().call_group("jugador", "set", "puede_conducir", true)
	get_tree().call_group("bots", "set", "puede_conducir", true)

func _update_timer(delta: float) -> void:
	if not is_timer_running:
		return
		
	time_elapsed += delta
	var minutes: int = int(time_elapsed / 60.0)
	var seconds: int = int(time_elapsed) % 60
	var msecs: int = int((time_elapsed - int(time_elapsed)) * 100)
	
	label_timer.text = "%02d:%02d:%02d" % [minutes, seconds, msecs]

func _update_vehicle_hud() -> void:
	if not vehicle:
		return
	
	# 1. Velocidad
	var speed_kmh: float = 0.0
	if "speed_kmh" in vehicle:
		speed_kmh = vehicle.speed_kmh
	elif "linear_velocity" in vehicle:
		speed_kmh = vehicle.linear_velocity.length() * 3.6
	label_speed.text = "%d km/h" % round(speed_kmh)

	# 2. Marcha
	if label_gear and vehicle.has_method("get_gear_text"):
		label_gear.text = vehicle.get_gear_text()

	# 3. RPM y alerta de corte en rojo
	var current_rpm: float = 0.0
	if vehicle.has_method("get_rpm"):
		current_rpm = vehicle.get_rpm()

	if progress_bar_rpm:
		progress_bar_rpm.value = current_rpm
		if rpm_fill_style:
			if current_rpm >= max_rpm * 0.85:
				rpm_fill_style.bg_color = Color(0.95, 0.15, 0.15) # Rojo alerta corte
			else:
				rpm_fill_style.bg_color = Color(1.0, 1.0, 1.0, 1.0) # Color normal
