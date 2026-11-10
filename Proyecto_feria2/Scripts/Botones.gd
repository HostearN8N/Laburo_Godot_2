
extends Button

# Buscamos el nodo hijo que hace de barra (asegurate de que se llame "BarraSeleccion")
@onready var barra: Control = $BarraSeleccion

@export var expanded_width: float = 210.0 # Ancho máximo al extenderse sobre la palabra
@export var compact_width: float = 6.0    # Ancho inicial (la barrita vertical compacta)
@export var anim_duration: float = 0.2    # Velocidad de la animación

func _ready() -> void:
	if barra:
		# Configuramos el tamaño inicial y permitemos que use custom_minimum_size
		barra.custom_minimum_size.x = compact_width
	
	# Conectamos las señales de mouse y foco (teclado/joystick)
	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func _on_focus_entered() -> void:
	if not barra: return
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 1. Se extiende a lo largo de la palabra
	tween.tween_property(barra, "custom_minimum_size:x", expanded_width, anim_duration)
	
	# 2. Se vuelve translúcido hacia el borde derecho para lograr el efecto difuminado
	tween.tween_property(barra, "modulate:a", 0.45, anim_duration)

func _on_focus_exited() -> void:
	if not barra: return
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 1. Vuelve a encogerse a la barrita vertical original
	tween.tween_property(barra, "custom_minimum_size:x", compact_width, anim_duration)
	
	# 2. Recupera su opacidad sólida
	tween.tween_property(barra, "modulate:a", 1.0, anim_duration)
