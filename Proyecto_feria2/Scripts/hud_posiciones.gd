extends Control
## HUD de posiciones. Se añade como un nodo Control hijo del nodo HUD.
## Construye su propia interfaz por código: no hay que crear labels a mano.
## Arriba a la izquierda: "POS 3/10" grande + lista de la clasificación.

@export var mostrar_lista: bool = true
@export var color_jugador: Color = Color(1.0, 0.85, 0.1)
@export var tam_fuente_posicion: int = 54
@export var tam_fuente_lista: int = 20
@export var margen: Vector2 = Vector2(24, 24)

var _gestor: GestorPosiciones
var _label_pos: Label
var _caja_lista: VBoxContainer
var _filas: Array[Label] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir_ui()

	# Esperamos un frame: el gestor se registra en su propio _ready
	await get_tree().process_frame
	_gestor = get_tree().get_first_node_in_group("gestor_carrera") as GestorPosiciones
	if _gestor == null:
		push_warning("HUD posiciones: no encuentro el GestorPosiciones en la escena.")
		return
	_gestor.clasificacion_actualizada.connect(_al_actualizar)


func _construir_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = margen
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var margen_interior := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen_interior.add_theme_constant_override("margin_" + lado, 10)
	panel.add_child(margen_interior)

	var vbox := VBoxContainer.new()
	margen_interior.add_child(vbox)

	_label_pos = Label.new()
	_label_pos.text = "POS --"
	_estilizar(_label_pos, tam_fuente_posicion, color_jugador)
	vbox.add_child(_label_pos)

	_caja_lista = VBoxContainer.new()
	_caja_lista.visible = mostrar_lista
	vbox.add_child(_caja_lista)


func _estilizar(label: Label, tam: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)


func _al_actualizar(orden: Array) -> void:
	var total := orden.size()
	var pos := orden.find(_gestor.jugador) + 1
	_label_pos.text = "POS %d/%d" % [pos, total]

	if not mostrar_lista:
		return

	# Crea las filas que falten (solo ocurre la primera vez)
	while _filas.size() < total:
		var nueva := Label.new()
		_estilizar(nueva, tam_fuente_lista, Color.WHITE)
		_caja_lista.add_child(nueva)
		_filas.append(nueva)

	for i in _filas.size():
		var fila := _filas[i]
		if i >= total:
			fila.visible = false
			continue
		var coche: Node3D = orden[i]
		var es_jugador := coche == _gestor.jugador
		fila.visible = true
		fila.text = "%d. %s" % [i + 1, "TÚ" if es_jugador else _nombre_bonito(coche)]
		fila.add_theme_color_override("font_color", color_jugador if es_jugador else Color.WHITE)


func _nombre_bonito(coche: Node) -> String:
	return String(coche.name).replace("_", " ")
