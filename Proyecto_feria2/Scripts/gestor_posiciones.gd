class_name GestorPosiciones
extends Node
## Calcula en qué posición va cada coche de la carrera.
## Colocar como hijo de Autodromo_Imola (hermano de los Fiat_500_Abarth*).
##
## Cómo funciona: proyecta cada coche sobre el Path3D del recorrido y mide
## cuántos metros ha avanzado desde la línea de meta (vueltas * largo + offset).
## Ordena de mayor a menor distancia recorrida.

signal clasificacion_actualizada(orden: Array)   # Array de Node3D, el índice 0 va primero
signal jugador_termino(posicion: int)            # se emite cuando TU coche termina la carrera

@export var path: Path3D                         ## Path3D del recorrido. Vacío = busca un nodo "Path3D"
@export var linea_meta: Node3D                   ## Nodo en la línea de meta. Vacío = busca un nodo "LineaMeta"
@export var nombre_jugador: StringName = &"Fiat_500_Abarth10"
@export var prefijo_coches: String = "Fiat_500_Abarth"
@export var total_vueltas: int = 3
@export var invertir_sentido: bool = false       ## Actívalo si el Path3D va al revés que la carrera
@export_range(0.02, 0.5) var intervalo: float = 0.1

var jugador: Node3D

var _coches: Array[Node3D] = []
var _datos: Dictionary = {}                      # coche -> { "rel": float, "vuelta": int }
var _terminados: Array[Node3D] = []
var _orden: Array[Node3D] = []
var _largo: float = 0.0
var _offset_meta: float = 0.0
var _acum: float = 0.0
var _listo: bool = false


func _ready() -> void:
	add_to_group("gestor_carrera")
	# Esperamos un frame para que todos los coches ya estén colocados en la parrilla
	await get_tree().process_frame
	_iniciar()


func _iniciar() -> void:
	var padre := get_parent()
	if path == null:
		path = padre.get_node_or_null("Path3D") as Path3D
	if linea_meta == null:
		linea_meta = padre.get_node_or_null("LineaMeta") as Node3D

	if path == null or path.curve == null:
		push_error("GestorPosiciones: falta el Path3D con la curva del recorrido.")
		return

	_largo = path.curve.get_baked_length()

	if linea_meta:
		_offset_meta = _offset_en_curva(linea_meta.global_position)
	else:
		push_warning("GestorPosiciones: no hay linea_meta, se usa el inicio del Path3D como meta.")

	for hijo in padre.get_children():
		if hijo is Node3D and String(hijo.name).begins_with(prefijo_coches):
			_coches.append(hijo)
			if hijo.name == nombre_jugador:
				jugador = hijo

	if jugador == null:
		push_warning("GestorPosiciones: no encuentro el coche del jugador '%s'." % nombre_jugador)

	# Los coches que están en la parrilla ANTES de la meta tienen un offset
	# cercano al final del path: arrancan en la vuelta -1 para que su progreso
	# sea ligeramente negativo y no "adelanten" a nadie por error.
	for c in _coches:
		var rel := _offset_relativo(c)
		_datos[c] = {"rel": rel, "vuelta": -1 if rel > _largo * 0.5 else 0}

	_listo = true


func _process(delta: float) -> void:
	if not _listo:
		return
	_acum += delta
	if _acum < intervalo:
		return
	_acum = 0.0
	_actualizar()


func _actualizar() -> void:
	var progreso: Dictionary = {}

	for c in _coches:
		var d: Dictionary = _datos[c]
		var rel := _offset_relativo(c)

		# Cruce de la línea de meta (salto del final del path al inicio, o al revés)
		if d["rel"] > _largo * 0.75 and rel < _largo * 0.25:
			d["vuelta"] += 1
		elif d["rel"] < _largo * 0.25 and rel > _largo * 0.75:
			d["vuelta"] -= 1
		d["rel"] = rel

		progreso[c] = d["vuelta"] * _largo + rel

		if d["vuelta"] >= total_vueltas and not _terminados.has(c):
			_terminados.append(c)
			if c == jugador:
				jugador_termino.emit(_terminados.size())

	# Primero los que ya terminaron (por orden de llegada), luego el resto por distancia
	var resto: Array[Node3D] = []
	for c in _coches:
		if not _terminados.has(c):
			resto.append(c)
	resto.sort_custom(func(a, b): return progreso[a] > progreso[b])

	_orden.clear()
	_orden.append_array(_terminados)
	_orden.append_array(resto)

	clasificacion_actualizada.emit(_orden)


func _offset_en_curva(pos_global: Vector3) -> float:
	var o := path.curve.get_closest_offset(path.to_local(pos_global))
	if invertir_sentido:
		o = _largo - o
	return o


func _offset_relativo(coche: Node3D) -> float:
	# Distancia recorrida desde la línea de meta, entre 0 y el largo del circuito
	return fposmod(_offset_en_curva(coche.global_position) - _offset_meta, _largo)


# --- API pública, por si la quieres usar desde otros scripts ---

func posicion_de(coche: Node3D) -> int:
	return _orden.find(coche) + 1


func posicion_jugador() -> int:
	return posicion_de(jugador) if jugador else 0


func vuelta_de(coche: Node3D) -> int:
	if not _datos.has(coche):
		return 1
	return clampi(int(_datos[coche]["vuelta"]) + 1, 1, total_vueltas)


func total_coches() -> int:
	return _coches.size()
