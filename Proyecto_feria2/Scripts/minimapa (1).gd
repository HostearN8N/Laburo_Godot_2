extends Control
## Minimapa estilo juego de carreras.
## Dibuja el trazado a partir del mismo Path3D que usa el GestorPosiciones
## y muestra un punto por cada coche (el tuyo en amarillo y más grande).
##
## Se añade como un nodo Control hijo del nodo HUD.
## Necesita que el GestorPosiciones esté en la escena de la pista.

enum Esquina { ABAJO_DERECHA, ABAJO_IZQUIERDA, ARRIBA_DERECHA, ARRIBA_IZQUIERDA }

@export_group("Tamaño y posición")
@export var esquina: Esquina = Esquina.ABAJO_DERECHA
@export var tam_mapa: Vector2 = Vector2(300, 220)
@export var margen: int = 24                       ## Distancia a la esquina inferior derecha
@export var autoposicionar: bool = true            ## Desactívalo si quieres colocar el nodo a mano en el editor
@export var relleno: float = 18.0                  ## Espacio libre entre el trazado y el borde del panel

@export_group("Orientación")
@export var rotacion_mapa: float = 0.0             ## En grados: 0, 90, 180 o 270 para girar el mapa

@export_group("Aspecto")
@export var paso_muestreo: float = 10.0            ## Cada cuántos metros toma un punto del Path3D
@export var ancho_pista: float = 6.0
@export var color_pista: Color = Color(0.6, 0.63, 0.7)
@export var color_borde_pista: Color = Color(0.04, 0.04, 0.07)
@export var color_fondo: Color = Color(0.05, 0.06, 0.1, 0.6)
@export var color_borde_panel: Color = Color(1, 1, 1, 0.35)
@export var color_bots: Color = Color(0.95, 0.3, 0.3)
@export var color_jugador: Color = Color(1.0, 0.85, 0.1)
@export var radio_bot: float = 5.0
@export var radio_jugador: float = 7.5

var _gestor: GestorPosiciones
var _coches: Array = []
var _pista_raw: PackedVector2Array = PackedVector2Array()   # trazado proyectado, sin escalar
var _pista: PackedVector2Array = PackedVector2Array()       # trazado ya ajustado al panel
var _meta_raw: Vector2 = Vector2.ZERO
var _meta_dir: Vector2 = Vector2.RIGHT
var _hay_meta: bool = false
var _centro_raw: Vector2 = Vector2.ZERO
var _escala: float = 1.0
var _intentado: bool = false
var _listo: bool = false
var _estilo_fondo: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if autoposicionar:
		custom_minimum_size = tam_mapa
		_posicionar()

	_estilo_fondo = StyleBoxFlat.new()
	_estilo_fondo.bg_color = color_fondo
	_estilo_fondo.border_color = color_borde_panel
	_estilo_fondo.set_border_width_all(2)
	_estilo_fondo.set_corner_radius_all(12)

	resized.connect(_ajustar)

	# Esperamos un frame: el gestor se registra en su propio _ready
	await get_tree().process_frame
	_gestor = get_tree().get_first_node_in_group("gestor_carrera") as GestorPosiciones
	if _gestor == null:
		push_warning("Minimapa: no encuentro el GestorPosiciones en la escena.")
		return
	_gestor.clasificacion_actualizada.connect(_al_actualizar)


func _posicionar() -> void:
	custom_minimum_size = tam_mapa

	var derecha := esquina == Esquina.ABAJO_DERECHA or esquina == Esquina.ARRIBA_DERECHA
	var abajo := esquina == Esquina.ABAJO_DERECHA or esquina == Esquina.ABAJO_IZQUIERDA

	# Anclamos las cuatro anclas a la misma esquina de la pantalla...
	var ax := 1.0 if derecha else 0.0
	var ay := 1.0 if abajo else 0.0
	anchor_left = ax
	anchor_right = ax
	anchor_top = ay
	anchor_bottom = ay

	# ...y ponemos los offsets a mano, así no depende del tamaño del padre
	if derecha:
		offset_left = -tam_mapa.x - margen
		offset_right = -margen
	else:
		offset_left = margen
		offset_right = margen + tam_mapa.x

	if abajo:
		offset_top = -tam_mapa.y - margen
		offset_bottom = -margen
	else:
		offset_top = margen
		offset_bottom = margen + tam_mapa.y


func _al_actualizar(orden: Array) -> void:
	_coches = orden.duplicate()
	# El trazado se construye en la primera actualización, cuando el gestor ya está iniciado
	if not _intentado:
		_intentado = true
		_construir_trazado()
		_ajustar()
		_listo = _pista.size() > 1


func _construir_trazado() -> void:
	var path: Path3D = _gestor.path
	if path == null or path.curve == null:
		push_warning("Minimapa: el gestor no tiene un Path3D con curva.")
		return

	var curva := path.curve
	var largo := curva.get_baked_length()
	if largo <= 0.0:
		return

	_pista_raw.clear()
	var d := 0.0
	while d < largo:
		_pista_raw.append(_proyectar(path.to_global(curva.sample_baked(d, true))))
		d += paso_muestreo
	_pista_raw.append(_pista_raw[0])   # cierra el circuito

	# Marca de la línea de meta
	var meta: Node3D = _gestor.linea_meta
	if meta:
		var off := curva.get_closest_offset(path.to_local(meta.global_position))
		_meta_raw = _proyectar(path.to_global(curva.sample_baked(off, true)))
		var a := _proyectar(path.to_global(curva.sample_baked(fposmod(off - 3.0, largo), true)))
		var b := _proyectar(path.to_global(curva.sample_baked(fposmod(off + 3.0, largo), true)))
		if a.distance_to(b) > 0.001:
			_meta_dir = (b - a).normalized()
		_hay_meta = true


# Vista cenital: X del mundo -> horizontal, Z del mundo -> vertical
func _proyectar(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z).rotated(deg_to_rad(rotacion_mapa))


func _ajustar() -> void:
	if _pista_raw.is_empty():
		return

	var minimo := _pista_raw[0]
	var maximo := _pista_raw[0]
	for p in _pista_raw:
		minimo = minimo.min(p)
		maximo = maximo.max(p)

	var dim := maximo - minimo
	var util := size - Vector2.ONE * (relleno * 2.0)
	_escala = minf(util.x / maxf(dim.x, 0.001), util.y / maxf(dim.y, 0.001))
	_centro_raw = (minimo + maximo) * 0.5

	_pista = PackedVector2Array()
	for p in _pista_raw:
		_pista.append(_a_mapa_raw(p))


func _a_mapa_raw(p: Vector2) -> Vector2:
	return (p - _centro_raw) * _escala + size * 0.5


func _a_mapa(p: Vector3) -> Vector2:
	return _a_mapa_raw(_proyectar(p))


func _process(_delta: float) -> void:
	if _listo:
		queue_redraw()


func _draw() -> void:
	draw_style_box(_estilo_fondo, Rect2(Vector2.ZERO, size))
	if not _listo:
		return

	# Pista: borde oscuro debajo y color claro encima
	draw_polyline(_pista, color_borde_pista, ancho_pista + 4.0, true)
	draw_polyline(_pista, color_pista, ancho_pista, true)

	# Línea de meta
	if _hay_meta:
		var m := _a_mapa_raw(_meta_raw)
		var perp := Vector2(-_meta_dir.y, _meta_dir.x) * (ancho_pista + 3.0)
		draw_line(m - perp, m + perp, Color.BLACK, 5.0)
		draw_line(m - perp, m + perp, Color.WHITE, 3.0)

	# Bots
	for c in _coches:
		if not is_instance_valid(c) or c == _gestor.jugador:
			continue
		var pos := _a_mapa(c.global_position)
		draw_circle(pos, radio_bot + 1.5, Color.BLACK)
		draw_circle(pos, radio_bot, color_bots)

	# Jugador, dibujado el último para que quede por encima
	if _gestor.jugador and is_instance_valid(_gestor.jugador):
		var pj := _a_mapa(_gestor.jugador.global_position)
		draw_circle(pj, radio_jugador + 2.5, Color.WHITE)
		draw_circle(pj, radio_jugador, color_jugador)
