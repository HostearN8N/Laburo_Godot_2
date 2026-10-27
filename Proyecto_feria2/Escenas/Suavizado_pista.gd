@tool
extends Path3D

@export var strength := 1.0
@export var closed_loop := true
@export var smooth_now := false:
	set(v):
		if v: _smooth()
		smooth_now = false

func _smooth() -> void:
	var n := curve.point_count
	if n < 3: return
	for i in n:
		var p := (i - 1 + n) % n if closed_loop else maxi(i - 1, 0)
		var q := (i + 1) % n if closed_loop else mini(i + 1, n - 1)
		
		# Obtenemos las posiciones
		var pos_p := curve.get_point_position(p)
		var pos_q := curve.get_point_position(q)
		var direction := pos_q - pos_p
		
		# Validamos que la dirección no sea un vector cero (evita el error)
		if direction.length_squared() > 0.0001:
			var t := direction / 6.0 * strength
			curve.set_point_in(i, -t)
			curve.set_point_out(i, t)
		else:
			# Si los puntos están superpuestos, dejamos los handles en cero de forma segura
			curve.set_point_in(i, Vector3.ZERO)
			curve.set_point_out(i, Vector3.ZERO)
			
