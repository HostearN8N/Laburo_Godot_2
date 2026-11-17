class_name BotGridManager
extends Node
## Reemplaza los bots de la grilla por el vehiculo que eligio el jugador en el
## concesionario.
##
## Uso: agregar un Node con este script como hijo de la escena del circuito
## (Autodromo_Imola). Al cargar la carrera lee Global.auto_seleccionado_path
## (la ruta de la escena jugable, por ejemplo "res://Autos/fiat_500_abarth.tscn"),
## busca la escena de bot de ese auto en BOT_SCENES_BY_PLAYER_FILE y cambia
## cada bot del grupo "bots" por una instancia de esa escena, conservando su
## plaza: posicion en la grilla, PathFollow3D, trazada y demas valores propios
## de cada bot (no del vehiculo).
##
## Si el auto no esta en el diccionario, prueba la convencion
## "<escena jugable>_bot.tscn" en la misma carpeta.
##
## Si no hay auto elegido, o no existe la escena de bot, no toca nada y los
## bots quedan como estan.
##
## Con debug_log activado, escribe en la Salida lo que hace, siempre con el
## prefijo [BotGridManager].


## Se emite cuando termino el cambio. Si otro script (HUD, manager de carrera,
## semaforo) guarda referencias a los bots, que las tome desde esta senal o
## busque el grupo "bots" mas tarde, no en su _ready().
signal bots_replaced(bots: Array[VehicleBody3D])

## Desactivalo si queres llamar a replace_bots() a mano.
@export var replace_on_ready: bool = true

## Escribe en la Salida que hace el manager.
@export var debug_log: bool = true

## Para pruebas: si se completa con la ruta de una escena jugable, se usa esa
## en vez de Global.auto_seleccionado_path (sirve para probar la pista con F6).
@export_file("*.tscn") var player_scene_override: String = ""

## Texto que se agrega al nombre de la escena jugable cuando el auto no esta
## en el diccionario: "fiat_500_abarth.tscn" -> "fiat_500_abarth_bot.tscn".
@export var bot_scene_suffix: String = "_bot"

## NOMBRE DEL ARCHIVO de la escena jugable -> RUTA de la escena de bot.
## Se compara solo el nombre del archivo (sin carpeta), asi no importa si la
## escena jugable esta en res://Autos o en res://escenas_autos.
## Respeta mayusculas, espacios y guiones bajos tal como estan en el disco.
## Al agregar un auto nuevo al concesionario, agregalo tambien aca.
const BOT_SCENES_BY_PLAYER_FILE: Dictionary = {
	"fiat_500_abarth.tscn": "res://Autos/fiat_500_abarth_bot.tscn",
	"Mini Cooper S.tscn": "res://Autos/Mini_Cooper_S_bot.tscn",
	"Ford Fiesta ST.tscn": "res://Autos/Ford_Fiesta_bot.tscn",
	"Bmw 128i.tscn": "res://Autos/Bmw_128i_bot.tscn",
	"golf gti.tscn": "res://Autos/Golf_gti_bot.tscn",
}

## Propiedades del script del bot que pertenecen a la PLAZA y no al vehiculo.
## Se copian del bot viejo al nuevo. Todo lo demas (motor, direccion,
## evasion, salida, recuperacion) viene de la escena de bot del vehiculo.
const SLOT_PROPERTIES: Array[StringName] = [
	&"path_follow",
	&"lateral_offset",
	&"lateral_profile",
	&"start_lateral_offset",
	&"merge_distance",
	&"capture_start_grid_offset",
]


func _ready() -> void:
	_log("listo, voy a reemplazar los bots cuando termine de cargar la escena.")

	if replace_on_ready:
		# Diferido: durante el _ready() el padre esta ocupado preparando a sus
		# hijos y Godot no deja agregar ni quitar nodos en ese momento.
		replace_bots.call_deferred()


## Ruta de la escena de bot que corresponde a una escena jugable.
func get_bot_scene_path(player_scene_path: String) -> String:

	var file_name: String = player_scene_path.get_file()

	if BOT_SCENES_BY_PLAYER_FILE.has(file_name):
		return str(BOT_SCENES_BY_PLAYER_FILE[file_name])

	return "%s%s.%s" % [
		player_scene_path.get_basename(),
		bot_scene_suffix,
		player_scene_path.get_extension()
	]


func replace_bots() -> void:

	var player_path: String = player_scene_override

	if player_path.is_empty():
		var selected: Variant = Global.auto_seleccionado_path
		player_path = "" if selected == null else str(selected)

	if player_path.is_empty():
		_warn("no hay auto elegido (Global.auto_seleccionado_path esta vacio). Los bots quedan como estan.")
		return

	var bot_path: String = get_bot_scene_path(player_path)

	_log("auto elegido: %s" % player_path)
	_log("escena de bot buscada: %s" % bot_path)

	if not ResourceLoader.exists(bot_path):
		_warn("no existe la escena de bot '%s'. Los bots quedan como estan." % bot_path)
		return

	var bot_scene := load(bot_path) as PackedScene

	if bot_scene == null:
		_warn("'%s' no es una escena valida." % bot_path)
		return

	var new_bots: Array[VehicleBody3D] = []
	var swapped: int = 0
	var already_correct: int = 0

	# Copia de la lista: vamos a modificar el arbol mientras la recorremos.
	var old_bots: Array[Node] = get_tree().get_nodes_in_group("bots")

	_log("bots encontrados en el grupo 'bots': %d" % old_bots.size())

	for node in old_bots:
		var old_bot := node as VehicleBody3D

		if old_bot == null or old_bot.get_parent() == null:
			continue

		# Si ya es el vehiculo correcto, se deja como esta.
		if old_bot.scene_file_path == bot_scene.resource_path:
			new_bots.append(old_bot)
			already_correct += 1
			continue

		var new_bot: VehicleBody3D = _swap_bot(old_bot, bot_scene)

		if new_bot != null:
			new_bots.append(new_bot)
			swapped += 1

	_log("reemplazados: %d | ya eran correctos: %d" % [swapped, already_correct])

	bots_replaced.emit(new_bots)


func _swap_bot(old_bot: VehicleBody3D, scene: PackedScene) -> VehicleBody3D:

	var instance: Node = scene.instantiate()
	var new_bot := instance as VehicleBody3D

	if new_bot == null:
		_warn("la raiz de '%s' no es un VehicleBody3D." % scene.resource_path)
		instance.free()
		return null

	var parent: Node = old_bot.get_parent()
	var slot_index: int = old_bot.get_index()
	var slot_name: StringName = old_bot.name
	var slot_transform: Transform3D = old_bot.global_transform

	# Configuracion de la plaza: pasa del bot viejo al nuevo antes de entrar
	# al arbol, para que el _ready() del nuevo ya la vea.
	for property_name in SLOT_PROPERTIES:
		new_bot.set(property_name, old_bot.get(property_name))

	# Se quita el viejo primero para que el nuevo pueda quedarse con el mismo
	# nombre sin que Godot lo renombre.
	parent.remove_child(old_bot)
	old_bot.queue_free()

	new_bot.name = slot_name
	parent.add_child(new_bot)
	parent.move_child(new_bot, slot_index)
	new_bot.global_transform = slot_transform

	return new_bot


func _log(message: String) -> void:
	if debug_log:
		print("[BotGridManager] ", message)


func _warn(message: String) -> void:
	push_warning("BotGridManager: " + message)
	print("[BotGridManager] AVISO: ", message)
