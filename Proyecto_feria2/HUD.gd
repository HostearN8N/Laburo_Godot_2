extends CanvasLayer

@onready var label_timer: Label = $Control/PanelContainer_Timer/MarginContainer/LabelTimer
@onready var label_speed: Label = $Control/PanelContainer_Speed/VBoxContainer/LabelSpeed
@onready var progress_bar_speed: ProgressBar = $Control/PanelContainer_Speed/VBoxContainer/ProgressBarspeed

@export var vehicle_path: NodePath
var vehicle: Node3D = null

# Cronómetro
var time_elapsed: float = 0.0
var is_timer_running: bool = true

func _ready() -> void:
	if vehicle_path:
		vehicle = get_node_or_null(vehicle_path)
	
	if progress_bar_speed:
		progress_bar_speed.min_value = 0
		progress_bar_speed.max_value = 220 

func _process(delta: float) -> void:
	_update_timer(delta)
	_update_speedometer()

func _update_timer(delta: float) -> void:
	if not is_timer_running:
		return
		
	time_elapsed += delta
	var minutes: int = int(time_elapsed / 60.0)
	var seconds: int = int(time_elapsed) % 60
	var msecs: int = int((time_elapsed - int(time_elapsed)) * 100)
	
	label_timer.text = "%02d:%02d:%02d" % [minutes, seconds, msecs]

func _update_speedometer() -> void:
	if not vehicle:
		return
	
	var speed_kmh: float = 0.0
	
	if "linear_velocity" in vehicle:
		speed_kmh = vehicle.linear_velocity.length() * 3.6
	elif vehicle.has_method("get_speed"):
		speed_kmh = vehicle.get_speed()

	label_speed.text = "%d km/h" % round(speed_kmh)
	if progress_bar_speed:
		progress_bar_speed.value = speed_kmh
