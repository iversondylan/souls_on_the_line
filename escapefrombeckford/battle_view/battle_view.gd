# battle_view.gd

class_name BattleView extends Node2D

@export var combatant_view_scene: PackedScene = preload("res://battle_view/combatant_view.tscn")

@onready var friendly_group: GroupView = $Group0
@onready var enemy_group: GroupView = $Group1
var sim_host: SimHost
var battle_ui: BattleUI
var event_player: BattleEventPlayer
var event_director: BattleEventDirector
#var _assets := BattleAssetCache.new()
var _playing := false

var combatants_by_cid: Dictionary = {}

func _ready() -> void:
	set_process(true)
	event_player = BattleEventPlayer.new()
	event_director = BattleEventDirector.new()
	event_director.bind(self)

func bind_log(log: BattleEventLog) -> void:
	event_player.bind_log(log)

func start_playback() -> void:
	_playing = true

func _process(_dt: float) -> void:
	if !_playing:
		return
	var max_beats := 10
	var n := 0
	while n < max_beats and event_player.has_next():
		var beat := event_player.next_beat()
		if beat.is_empty():
			break
		event_director.play_beat(beat)
		n += 1

func get_or_create_combatant_view(cid: int, group_index: int, insert_index: int) -> CombatantView:
	if cid <= 0:
		return null
	if combatants_by_cid.has(cid):
		return combatants_by_cid[cid]

	var v := combatant_view_scene.instantiate()
	if v == null or !(v is CombatantView):
		push_error("BattleView: combatant_view_scene must instance a CombatantView")
		return null

	var group : GroupView = friendly_group if group_index == 0 else enemy_group
	group.add_child(v)

	var cv := v as CombatantView
	cv.cid = cid
	#cv.bind_assets(_assets)

	# Optional insert
	var n_children := group.get_child_count()
	if insert_index < 0:
		insert_index = n_children - 1
	insert_index = clampi(insert_index, 0, n_children - 1)
	group.move_child(cv, insert_index)

	combatants_by_cid[cid] = cv
	group.register_view(cv) # triggers layout
	return cv

func set_group_order(group_index: int, order: Array) -> void:
	var group : GroupView = friendly_group if group_index == 0 else enemy_group
	group.set_order(order)

func get_combatant(cid: int) -> CombatantView:
	return combatants_by_cid.get(cid, null)
