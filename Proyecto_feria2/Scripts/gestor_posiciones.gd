class_name GestorPosiciones
extends Node
## Calcula en qué posición va cada coche de la carrera y cronometra tus vueltas.
## Colocar como hijo de Autodromo_Imola (hermano de los Fiat_500_Abarth*).
##
## Posiciones: proyecta cada coche sobre el Path3D del recorrido y mide cuántos
## metros ha avanzado desde la línea de meta (vueltas * largo + offset).
##
## Vueltas y fin de carrera del JUGADOR: se toman de tu LineaMeta (linea_meta.gd),
## usando sus señales vuelta_cambiada y carrera_terminada, y su variable
## vueltas_totales. Así la pantalla de resultados aparece justo cuando sale el
## "¡FIN!". Si no hay LineaMeta, el gestor detecta las vueltas por el Path3D.

signal clasificacion_actualizada(orden: Array)   # Array de Node3D, el índice 0 va primero
signal jugador_termino(posicion: int)            # se emite cuando TU coche termina la carrera
signal vuelta_completada(numero: int, tiempo: float, es_mejor: bool)
signal resultados_jugador(datos: Dictionary)     # resumen final para la pantalla de resultados

@export var path: Path3D                         ## Path3D del recorrido. Vacío = busca un nodo "Path3D"
@export var linea_meta: Node3D                   ## Nodo en la línea de meta. Vacío = busca un nodo "LineaMeta"
@export var nombre_jugador: StringName = &"Fiat_500_Abarth10"
@export var prefijo_coches: String = "Fiat_500_Abarth"
@export var total_vueltas: int = 3               ## Si hay LineaMeta, se toma de su "vueltas_totales"
@export var sincronizar_con_linea_meta: bool = true
@export var invertir_sentido: bool = false       ## Actívalo si el Path3D va al revés que la carrera
@export_range(0.02, 0.5) var intervalo: float = 0.1

@export_group("Cronómetro")
@export var inicio_automatico: bool = true       ## Arranca el cronómetro cuando el jugador se mueve
@export var umbral_arranque: float = 1.0         ## Metros que debe moverse el jugador para dar la carrera por iniciada

var jugador: Node3D
var mejor_vuelta: float = -1.0                   ## En segundos. -1 = todavía no hay vuelta completa
var tiempo_total: float = -1.0                   ## En segundos. -1 = el jugador aún no terminó
var tiempos_vuelta: Array[float] = []

var _coches: Array[Node3D] = []
var _datos: Dictionary = {}                      # coche -> { "rel": float, "vuelta": int, "t": float }
var _terminados: Array[Node3D] = []
var _orden: Array[Node3D] = []
var _largo: float = 0.0
var _offset_meta: float = 0.0
var _acum: float = 0.0
var _listo: bool = false
var _usa_linea_meta: bool = false                # true = vueltas y fin del jugador los decide LineaMeta

var _reloj: float = 0.0                          # segundos de juego (se detiene con la pausa)
var _t_inicio: float = -1.0                      # -1 = la carrera aún no arrancó
var _t_vuelta: float = 0.0
var _pos_inicial: Vector2 = Vector2.ZERO
var _max_vuelta_jugador: int = -1


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
		_datos[c] = {"rel": rel, "vuelta": -1 if rel > _largo * 0.5 else 0, "t": _reloj}

	if jugador:
		_max_vuelta_jugador = _datos[jugador]["vuelta"]
		_pos_inicial = Vector2(jugador.global_position.x, jugador.global_position.z)

	_vincular_linea_meta()
	if sincronizar_con_linea_meta and not _usa_linea_meta:
		push_warning("GestorPosiciones: no encontré tu LineaMeta (grupo 'linea_meta' con las señales vuelta_cambiada y carrera_terminada). Las vueltas se cuentan por el Path3D.")
	_listo = true


func _vincular_linea_meta() -> void:
	if not sincronizar_con_linea_meta:
		return

	# Tu linea_meta.gd se añade sola al grupo "linea_meta"
	var nodo_meta: Node = null
	for n in get_tree().get_nodes_in_group("linea_meta"):
		if n.has_signal("vuelta_cambiada") and n.has_signal("carrera_terminada"):
			nodo_meta = n
			break
	if nodo_meta == null:
		nodo_meta = linea_meta
	if nodo_meta == null:
		return
	if not nodo_meta.has_signal("vuelta_cambiada") or not nodo_meta.has_signal("carrera_terminada"):
		return

	var v: Variant = nodo_meta.get("vueltas_totales")
	if v != null:
		total_vueltas = int(v)

	nodo_meta.connect("vuelta_cambiada", _al_vuelta_cambiada)
	nodo_meta.connect("carrera_terminada", _al_carrera_terminada)
	_usa_linea_meta = true
	print("GestorPosiciones: vinculado a LineaMeta (%d vueltas)" % total_vueltas)


func _process(delta: float) -> void:
	if not _listo:
		return

	_reloj += delta

	# Arranque automático del cronómetro (solo cuenta el movimiento horizontal)
	if _t_inicio < 0.0 and inicio_automatico and jugador:
		var p := Vector2(jugador.global_position.x, jugador.global_position.z)
		if p.distance_to(_pos_inicial) > umbral_arranque:
			iniciar_cronometro()

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
			if c == jugador and not _usa_linea_meta:
				_jugador_cruza_meta(_tiempo_de_cruce(d["rel"], rel, d["t"]))
		elif d["rel"] < _largo * 0.25 and rel > _largo * 0.75:
			d["vuelta"] -= 1
		d["rel"] = rel
		d["t"] = _reloj

		progreso[c] = d["vuelta"] * _largo + rel

		# Fin de carrera: el del jugador lo decide LineaMeta si está vinculada
		var llego: bool = d["vuelta"] >= total_vueltas and not _terminados.has(c)
		if llego and (c != jugador or not _usa_linea_meta):
			_terminados.append(c)
			if c == jugador:
				_terminar_jugador()

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


# --- Cronómetro ---

func iniciar_cronometro() -> void:
	## Llámalo cuando se apague el semáforo si no quieres el arranque automático.
	if _t_inicio >= 0.0:
		return
	_t_inicio = _reloj
	_t_vuelta = _reloj


func _registrar_vuelta(numero: int, tiempo: float) -> void:
	tiempos_vuelta.append(tiempo)
	var es_mejor := mejor_vuelta < 0.0 or tiempo < mejor_vuelta
	if es_mejor:
		mejor_vuelta = tiempo
	vuelta_completada.emit(numero, tiempo, es_mejor)


# Con LineaMeta vinculada: se llama cada vez que cruzas la meta
# (actual = 1 es la salida; actual >= 2 significa que acabas de completar una vuelta)
func _al_vuelta_cambiada(actual: int, _total: int) -> void:
	if _t_inicio < 0.0:
		iniciar_cronometro()
	if actual >= 2:
		_registrar_vuelta(actual - 1, _reloj - _t_vuelta)
	_t_vuelta = _reloj


# Con LineaMeta vinculada: se llama en el cruce final, el mismo momento del "¡FIN!"
func _al_carrera_terminada() -> void:
	print("GestorPosiciones: LineaMeta avisó el fin de carrera")
	if jugador == null or _terminados.has(jugador):
		return
	if _t_inicio >= 0.0:
		_registrar_vuelta(total_vueltas, _reloj - _t_vuelta)
		tiempo_total = _reloj - _t_inicio
	_terminados.append(jugador)
	_terminar_jugador()


# Sin LineaMeta: estima el instante exacto del cruce repartiendo el intervalo entre las dos lecturas
func _tiempo_de_cruce(rel_anterior: float, rel_nuevo: float, t_anterior: float) -> float:
	var antes := _largo - rel_anterior   # metros que le faltaban para la meta
	var despues := rel_nuevo             # metros que ya había pasado de la meta
	var total := antes + despues
	if total <= 0.0:
		return _reloj
	return t_anterior + (_reloj - t_anterior) * (antes / total)


# Sin LineaMeta: vueltas detectadas por el Path3D
func _jugador_cruza_meta(t_cruce: float) -> void:
	var v: int = _datos[jugador]["vuelta"]
	# Si el jugador retrocedió y volvió a cruzar, no cuenta como vuelta nueva
	if v <= _max_vuelta_jugador:
		return
	_max_vuelta_jugador = v

	if _t_inicio >= 0.0:
		if v >= 1:
			_registrar_vuelta(v, t_cruce - _t_vuelta)
		if v >= total_vueltas and tiempo_total < 0.0:
			tiempo_total = t_cruce - _t_inicio
	_t_vuelta = t_cruce


func _terminar_jugador() -> void:
	var posicion := _terminados.size()
	jugador_termino.emit(posicion)
	resultados_jugador.emit({
		"posicion": posicion,
		"total_coches": _coches.size(),
		"total_vueltas": total_vueltas,
		"tiempo_total": tiempo_total,
		"mejor_vuelta": mejor_vuelta,
		"tiempos_vuelta": tiempos_vuelta.duplicate(),
	})


# --- Cálculo de posiciones ---

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


func tiempo_carrera() -> float:
	## Segundos desde que arrancó la carrera (0 si aún no arrancó)
	if _t_inicio < 0.0:
		return 0.0
	return (tiempo_total if tiempo_total >= 0.0 else _reloj - _t_inicio)


func tiempo_vuelta_actual() -> float:
	if _t_inicio < 0.0:
		return 0.0
	return _reloj - _t_vuelta
