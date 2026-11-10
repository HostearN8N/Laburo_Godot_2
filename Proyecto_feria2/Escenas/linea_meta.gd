extends Area3D

signal vuelta_cambiada(actual: int, total: int)
signal carrera_terminada

@export var vueltas_totales: int = 3

var vuelta_actual: int = 0   # 0 = la carrera aún no empezó
var terminada: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	print("Entró: ", body.name, " | jugador: ", body.is_in_group("jugador"))
	if terminada or not body.is_in_group("jugador"):
		return

	# Ignorar si cruza en sentido contrario
	var coche := body as RigidBody3D
	if coche == null:
		return
	var adelante: Vector3 = -global_transform.basis.z
	if coche.linear_velocity.dot(adelante) <= 0.0:
		return

	if vuelta_actual == 0:
		vuelta_actual = 1              # primer cruce = salida
	elif vuelta_actual >= vueltas_totales:
		terminada = true
		carrera_terminada.emit()
		print("¡Carrera terminada!")
		return
	else:
		vuelta_actual += 1             # cruce posterior = nueva vuelta

	vuelta_cambiada.emit(vuelta_actual, vueltas_totales)
	print("Vuelta ", vuelta_actual, " / ", vueltas_totales)
