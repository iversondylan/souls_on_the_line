# battle_view.gd

class_name BattleView extends Node2D

@export var sim_host_path: NodePath

@export var friendly_container_path: NodePath
@export var enemy_container_path: NodePath
@export var fx_layer_path: NodePath

@export var combatant_view_scene: PackedScene

@onready var _sim_host: Node = get_node_or_null(sim_host_path)
@onready var _friendly: Node = get_node_or_null(friendly_container_path)
@onready var _enemy: Node = get_node_or_null(enemy_container_path)
@onready var _fx: Node = get_node_or_null(fx_layer_path)

var _player: BattleEventPlayer
var _director: BattleEventDirector

# cid -> CombatantView
var views_by_cid: Dictionary = {}

# Playback controls
var playback_enabled: bool = true
var playback_speed: float = 1.0

func _ready() -> void:
	_player = BattleEventPlayer.new()
	_director = BattleEventDirector.new()
	_director.bind(self)

func bind_log(log: BattleEventLog) -> void:
	_player.bind_log(log)
	# You may want to clear view registry here for new battles:
	# reset_view()

func reset_view() -> void:
	for cid in views_by_cid.keys():
		var v: Node = views_by_cid[cid]
		if is_instance_valid(v):
			v.queue_free()
	views_by_cid.clear()

func _process(_dt: float) -> void:
	if !playback_enabled:
		return
	if _player == null or _director == null:
		return

	# Drive playback without recursion:
	# If you want to prevent long loops in a single frame, cap max events per frame.
	var max_events := 50
	var n := 0
	while n < max_events and _player.has_next():
		var e := _player.next_event()
		if e == null:
			break

		# Note: director methods can be async later. For now, immediate.
		_director.on_event(e)
		n += 1

# --- VIEW helpers for Director ---

func get_or_create_combatant_view(cid: int, group_index: int, insert_index: int) -> CombatantView:
	if cid <= 0:
		return null

	if views_by_cid.has(cid):
		return views_by_cid[cid]

	if combatant_view_scene == null:
		push_error("BattleView: combatant_view_scene not assigned")
		return null

	var v := combatant_view_scene.instantiate()
	if v == null or !(v is CombatantView):
		push_error("BattleView: combatant_view_scene must instance a CombatantView")
		return null

	var parent := _friendly if int(group_index) == 0 else _enemy
	if parent == null:
		push_error("BattleView: missing formation containers")
		return null

	parent.add_child(v)
	(v as CombatantView).cid = cid

	# Insert ordering (basic)
	if insert_index >= 0 and insert_index < parent.get_child_count():
		parent.move_child(v, insert_index)

	views_by_cid[cid] = v
	return v

func get_view(cid: int) -> CombatantView:
	return views_by_cid.get(cid, null)

func set_group_order(group_index: int, order: Array) -> void:
	var parent := _friendly if int(group_index) == 0 else _enemy
	if parent == null:
		return

	# Reorder children according to order array of cids
	for i in range(order.size()):
		var cid := int(order[i])
		var v: CombatantView = views_by_cid.get(cid, null)
		if v != null and v.get_parent() == parent:
			parent.move_child(v, i)
