class_name PantallaResultados
extends Node
## Pantalla de fin de carrera que se arma sola por código (no necesita escena).
##
## Uso: agregá un Node hijo de Autodromo_Imola, ponele este script y elegí en el
## Inspector la "Escena Garaje". Se conecta solo a la señal resultados_jugador de
## tu GestorPosiciones (lo busca por el grupo "gestor_carrera").
##
## Muestra: puesto final, mejor vuelta, tiempo total, tiempos por vuelta, confeti
## si quedás en el podio, aviso de nuevo récord de pista, y te manda al garaje
## con un fundido a negro cuando termina la cuenta regresiva (o con Enter).

const RUTA_RECORDS := "user://records.cfg"
const COL_GRIS := Color(0.56, 0.64, 0.72)
const COL_MORADO := Color(0.78, 0.49, 1.0)
const COL_ORO := Color(1.0, 0.79, 0.2)
const COL_PLATA := Color(0.84, 0.86, 0.9)
const COL_BRONCE := Color(0.85, 0.54, 0.29)
const COL_AZUL := Color(0.36, 0.75, 1.0)

@export_file("*.tscn", "*.scn") var escena_garaje: String = ""   ## Escena a la que se vuelve al terminar
@export var segundos_en_pantalla: float = 6.5                    ## Cuánto dura la pantalla antes de ir al garaje
@export var retraso_inicial: float = 1.5                         ## Espera tras cruzar la meta (así se ve el "¡FIN!")
@export var guardar_records: bool = true                         ## Guarda la mejor vuelta por pista en user://records.cfg
@export var fuente: Font                                         ## Opcional: tu fuente de carreras
@export var sonido: AudioStream                                  ## Opcional: sonido al aparecer la pantalla
@export var capa: int = 60                                       ## Capa del CanvasLayer (más alto = más arriba)
@export var gestor: Node                                         ## Vacío = busca el grupo "gestor_carrera"


## Banda de cuadros de largada/llegada que se desplaza sola
class Banda extends Control:
	var velocidad: float = 50.0
	var lado: float = 14.0
	var claro := Color(1, 1, 1, 0.92)
	var oscuro := Color(0.04, 0.04, 0.05, 0.92)
	var _desp: float = 0.0

	func _process(delta: float) -> void:
		_desp = fposmod(_desp + velocidad * delta, lado * 2.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), oscuro)
		var filas := ceili(size.y / lado)
		var cols := ceili(size.x / lado) + 3
		for f in filas:
			for c in cols:
				if (f + c) % 2 == 0:
					draw_rect(Rect2((c - 2) * lado + _desp, f * lado, lado, lado), claro)


var _capa: CanvasLayer
var _raiz: Control
var _lbl_cuenta: Label
var _barra: ProgressBar
var _escala: float = 1.0
var _duracion: float = 6.5
var _restante: float = 0.0
var _mostrando: bool = false
var _contando: bool = false
var _puede_saltar: bool = false
var _yendo: bool = false


func _ready() -> void:
	# Esperamos un frame para que el gestor ya esté en su grupo
	await get_tree().process_frame
	if gestor == null:
		gestor = get_tree().get_first_node_in_group("gestor_carrera")
	if gestor == null or not gestor.has_signal("resultados_jugador"):
		push_error("PantallaResultados: no encuentro el GestorPosiciones (grupo 'gestor_carrera').")
		return
	gestor.connect("resultados_jugador", _al_resultados)


func _al_resultados(datos: Dictionary) -> void:
	if _mostrando:
		return
	_mostrando = true
	await get_tree().create_timer(retraso_inicial).timeout
	if not is_inside_tree():
		return
	_construir(datos)


func _process(delta: float) -> void:
	if not _contando:
		return
	_restante -= delta
	_barra.value = clampf(_restante / _duracion, 0.0, 1.0)
	_lbl_cuenta.text = "Volviendo al garaje en %d" % maxi(ceili(_restante), 0)
	if _restante <= 0.0:
		_ir_al_garaje()


func _input(event: InputEvent) -> void:
	if _puede_saltar and not _yendo and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_ir_al_garaje()


# --- Construcción de la pantalla ---

func _construir(d: Dictionary) -> void:
	var pos: int = d.get("posicion", 0)
	var total_coches: int = d.get("total_coches", 0)
	var total_vueltas: int = d.get("total_vueltas", 0)
	var tiempo_total: float = d.get("tiempo_total", -1.0)
	var mejor: float = d.get("mejor_vuelta", -1.0)
	var vueltas: Array = d.get("tiempos_vuelta", [])

	var tam_pantalla := get_viewport().get_visible_rect().size
	_escala = clampf(tam_pantalla.y / 720.0, 0.6, 2.0)
	_duracion = maxf(segundos_en_pantalla, 0.5)
	var podio := pos >= 1 and pos <= 3
	var acento := _color_acento(pos)
	var rec := _gestionar_record(mejor)
	var nuevo_record: bool = rec["nuevo"]
	var record_anterior: float = rec["anterior"]

	_capa = CanvasLayer.new()
	_capa.layer = capa
	add_child(_capa)

	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	if fuente:
		var tema := Theme.new()
		tema.default_font = fuente
		_raiz.theme = tema
	_capa.add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Fondo oscuro que se funde
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.03, 0.06, 0.0)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_tween().tween_property(fondo, "color:a", 0.8, 0.6)

	# Bandas de cuadros arriba y abajo, corriendo en sentidos opuestos
	_agregar_banda(true)
	_agregar_banda(false)

	# Panel central
	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_s(560), 0)
	panel.add_theme_stylebox_override("panel", _estilo_panel(acento))
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", _s(4))
	panel.add_child(caja)

	caja.add_child(_label(_titular(pos), _fs(46), acento))
	var txt_vueltas := "1 vuelta" if total_vueltas == 1 else "%d vueltas" % total_vueltas
	caja.add_child(_label("%s en %s" % [txt_vueltas, _nombre_pista()], _fs(15), COL_GRIS))

	var linea := ColorRect.new()
	linea.color = Color(acento, 0.45)
	linea.custom_minimum_size = Vector2(0, maxi(2, _s(2)))
	caja.add_child(linea)

	# El puesto: es lo más grande de la pantalla, cuenta hasta tu posición
	var desde := maxi(total_coches, pos)
	var lbl_puesto := _label("%d°" % desde, _fs(110), acento if podio else Color.WHITE)
	lbl_puesto.resized.connect(func() -> void: lbl_puesto.pivot_offset = lbl_puesto.size / 2.0)
	caja.add_child(lbl_puesto)
	if total_coches > 0:
		caja.add_child(_label("puesto de %d" % total_coches, _fs(18), COL_GRIS))

	var tw_puesto := create_tween()
	tw_puesto.tween_interval(0.5)
	tw_puesto.tween_method(
		func(v: float) -> void: lbl_puesto.text = "%d°" % roundi(v),
		float(desde), float(pos), 1.1
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_puesto.tween_callback(_punch.bind(lbl_puesto))

	_espaciador(caja, 6)

	# Mejor vuelta y tiempo total
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", _s(48))
	caja.add_child(stats)
	var lbl_mejor := _bloque_tiempo(stats, "Mejor vuelta", COL_MORADO)
	var lbl_total := _bloque_tiempo(stats, "Tiempo total", Color.WHITE)
	_fade(stats, 1.0)
	_contar_tiempo(lbl_mejor, mejor, 1.05)
	_contar_tiempo(lbl_total, tiempo_total, 1.05)

	# Récord de pista
	if nuevo_record:
		var badge := _label("¡Nuevo récord de pista!", _fs(20), COL_ORO)
		caja.add_child(badge)
		_fade(badge, 2.2, 0.3)
		_punch_diferido(badge, 2.2)
	elif record_anterior > 0.0:
		var ref := _label("Récord de pista: %s" % _fmt(record_anterior), _fs(15), COL_GRIS)
		caja.add_child(ref)
		_fade(ref, 2.0)

	# Tiempos por vuelta (solo si entran cómodos en pantalla)
	if vueltas.size() > 1 and vueltas.size() <= 6:
		_espaciador(caja, 6)
		var lista := VBoxContainer.new()
		lista.add_theme_constant_override("separation", _s(2))
		caja.add_child(lista)
		var marcada := false
		for i in vueltas.size():
			var t: float = vueltas[i]
			var es_mejor := not marcada and is_equal_approx(t, mejor)
			if es_mejor:
				marcada = true
			var col := COL_MORADO if es_mejor else COL_GRIS
			var fila := HBoxContainer.new()
			var izq := _label("Vuelta %d%s" % [i + 1, "  (mejor)" if es_mejor else ""], _fs(16), col, HORIZONTAL_ALIGNMENT_LEFT)
			izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fila.add_child(izq)
			fila.add_child(_label(_fmt(t), _fs(16), col, HORIZONTAL_ALIGNMENT_RIGHT))
			lista.add_child(fila)
			_fade(fila, 2.0 + i * 0.12)

	# Cuenta regresiva hacia el garaje
	_espaciador(caja, 10)
	_lbl_cuenta = _label("", _fs(15), COL_GRIS)
	caja.add_child(_lbl_cuenta)

	_barra = ProgressBar.new()
	_barra.min_value = 0.0
	_barra.max_value = 1.0
	_barra.step = 0.001
	_barra.value = 1.0
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(0, maxi(4, _s(6)))
	_barra.add_theme_stylebox_override("background", _estilo_barra(Color(1, 1, 1, 0.12)))
	_barra.add_theme_stylebox_override("fill", _estilo_barra(acento))
	caja.add_child(_barra)

	var hint := _label("Enter para ir ahora", _fs(13), COL_GRIS)
	caja.add_child(hint)
	_fade(hint, 2.0)

	# Entrada del panel
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.88, 0.88)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	var tw_panel := create_tween().set_parallel(true)
	tw_panel.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw_panel.tween_property(panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if podio or nuevo_record:
		_lanzar_confeti(tam_pantalla.x, 170 if pos == 1 else 110)

	if sonido:
		var ap := AudioStreamPlayer.new()
		ap.stream = sonido
		add_child(ap)
		ap.play()

	get_tree().create_timer(2.0).timeout.connect(func() -> void: _puede_saltar = true)
	_restante = _duracion
	_contando = true


func _agregar_banda(arriba: bool) -> void:
	var alto := _s(28)
	var b := Banda.new()
	b.lado = alto / 2.0
	b.velocidad = (50.0 if arriba else -50.0) * _escala
	b.clip_contents = true
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(b)
	if arriba:
		b.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		b.offset_bottom = alto
	else:
		b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		b.offset_top = -alto
	_fade(b, 0.2, 0.5)


func _lanzar_confeti(ancho: float, cantidad: int) -> void:
	# Papelitos rectangulares de colores que caen desde arriba
	var img := Image.create_empty(8, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([COL_ORO, Color(1.0, 0.3, 0.43), COL_AZUL, Color(0.49, 1.0, 0.7), COL_MORADO])

	var c := CPUParticles2D.new()
	c.texture = ImageTexture.create_from_image(img)
	c.amount = cantidad
	c.lifetime = 4.0
	c.lifetime_randomness = 0.3
	c.one_shot = true
	c.explosiveness = 0.0
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	c.emission_rect_extents = Vector2(ancho * 0.5, 4.0)
	c.position = Vector2(ancho * 0.5, -12.0)
	c.direction = Vector2.DOWN
	c.spread = 28.0
	c.gravity = Vector2(0.0, 240.0 * _escala)
	c.initial_velocity_min = 120.0 * _escala
	c.initial_velocity_max = 280.0 * _escala
	c.angle_min = 0.0
	c.angle_max = 360.0
	c.angular_velocity_min = -420.0
	c.angular_velocity_max = 420.0
	c.scale_amount_min = 1.0 * _escala
	c.scale_amount_max = 1.8 * _escala
	c.color_initial_ramp = g
	_capa.add_child(c)
	c.emitting = true


# --- Salida hacia el garaje ---

func _ir_al_garaje() -> void:
	if _yendo:
		return
	_contando = false
	if escena_garaje.is_empty() or not ResourceLoader.exists(escena_garaje):
		_puede_saltar = false
		push_error("PantallaResultados: elegí la escena del garaje en el Inspector (propiedad 'Escena Garaje').")
		_lbl_cuenta.text = "Falta configurar la escena del garaje"
		return

	_yendo = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var negro := ColorRect.new()
	negro.color = Color(0, 0, 0, 0)
	negro.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.add_child(negro)
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tw := create_tween()
	tw.tween_property(negro, "color:a", 1.0, 0.4)
	tw.tween_callback(get_tree().change_scene_to_file.bind(escena_garaje))


# --- Récord de pista ---

func _gestionar_record(mejor: float) -> Dictionary:
	var res := {"nuevo": false, "anterior": -1.0}
	if not guardar_records or mejor <= 0.0:
		return res

	var cfg := ConfigFile.new()
	cfg.load(RUTA_RECORDS)   # si el archivo no existe todavía, no pasa nada
	var clave := _clave_pista()
	var anterior: float = cfg.get_value("mejor_vuelta", clave, -1.0)
	res["anterior"] = anterior

	if anterior < 0.0 or mejor < anterior:
		res["nuevo"] = true
		cfg.set_value("mejor_vuelta", clave, mejor)
		cfg.save(RUTA_RECORDS)
	return res


func _clave_pista() -> String:
	var escena := get_tree().current_scene
	if escena and not escena.scene_file_path.is_empty():
		return escena.scene_file_path.get_file().get_basename()
	return "pista"


func _nombre_pista() -> String:
	return _clave_pista().capitalize()


# --- Utilidades de UI ---

func _s(px: float) -> int:
	return maxi(1, roundi(px * _escala))


func _fs(px: float) -> int:
	return maxi(11, roundi(px * _escala))


func _label(texto: String, tam: int, color: Color = Color.WHITE, alin: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = alin
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(2, int(tam * 0.08)))
	return l


func _espaciador(padre: Control, px: float) -> void:
	var e := Control.new()
	e.custom_minimum_size = Vector2(0, _s(px))
	padre.add_child(e)


func _bloque_tiempo(padre: Control, titulo: String, color: Color) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	padre.add_child(v)
	v.add_child(_label(titulo, _fs(15), COL_GRIS))
	var valor := _label(_fmt(0.0), _fs(34), color)
	v.add_child(valor)
	return valor


func _estilo_panel(acento: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(0.05, 0.07, 0.11, 0.94)
	e.border_color = acento
	e.set_border_width_all(maxi(2, _s(3)))
	e.set_corner_radius_all(_s(18))
	e.set_content_margin_all(_s(24))
	e.shadow_color = Color(acento, 0.35)
	e.shadow_size = _s(22)
	return e


func _estilo_barra(color: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = color
	e.set_corner_radius_all(_s(4))
	return e


func _fade(c: CanvasItem, demora: float, dur: float = 0.35) -> void:
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, dur).set_delay(demora)


func _punch(c: Control) -> void:
	c.scale = Vector2(1.35, 1.35)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _punch_diferido(c: Control, demora: float) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2.0)
	var tw := create_tween()
	tw.tween_interval(demora)
	tw.tween_callback(_punch.bind(c))


func _contar_tiempo(lbl: Label, hasta: float, demora: float) -> void:
	if hasta < 0.0:
		lbl.text = _fmt(hasta)
		return
	create_tween().tween_method(
		func(v: float) -> void: lbl.text = _fmt(v),
		0.0, hasta, 1.2
	).set_delay(demora).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _titular(p: int) -> String:
	match p:
		1:
			return "¡VICTORIA!"
		2, 3:
			return "¡AL PODIO!"
		_:
			return "CARRERA TERMINADA"


func _color_acento(p: int) -> Color:
	match p:
		1:
			return COL_ORO
		2:
			return COL_PLATA
		3:
			return COL_BRONCE
		_:
			return COL_AZUL


static func _fmt(t: float) -> String:
	## Formato m:ss.mmm (o --:--.--- si no hay tiempo)
	if t < 0.0:
		return "--:--.---"
	var ms_total := roundi(t * 1000.0)
	var m := floori(ms_total / 60000.0)
	var s := floori((ms_total % 60000) / 1000.0)
	var ms := ms_total % 1000
	return "%d:%02d.%03d" % [m, s, ms]
