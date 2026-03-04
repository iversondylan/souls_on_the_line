# battle_view.gd

class_name BattleView extends Node2D

@onready var combatant_view_scene: PackedScene = preload("res://battle_view/combatant_view.tscn")

@onready var friendly_group: GroupView = $Group0
@onready var enemy_group: GroupView = $Group1

var sim_host: SimHost
var battle_ui: BattleUI

var event_player: BattleEventPlayer
var event_director: BattleEventDirector
var transport: BattleTransport
#var _assets := BattleAssetCache.new()

var _playing := false
var _playback_gen: int = 0

var combatants_by_cid: Dictionary = {}

# Playback knobs
var tempo: float = 130
#@export var beat_gap_sec: float = 0.12
#@export var scope_gap_sec: float = 0.20

func _ready() -> void:
	event_player = BattleEventPlayer.new()
	event_director = BattleEventDirector.new()
	event_director.bind(self)
	transport = BattleTransport.new()
	transport.tempo = tempo

func bind_log(log: BattleEventLog) -> void:
	event_player.bind_log(log)

func start_playback() -> void:
	if _playing:
		return
	_playing = true
	_playback_gen += 1
	_playback_loop(_playback_gen) # fire-and-forget coroutine

func stop_playback() -> void:
	_playing = false
	_playback_gen += 1 # invalidates any running loop

# battle_view.gd
func _playback_loop(gen: int) -> void:
	while _playing and gen == _playback_gen and event_player != null:
		# If we reached end-of-log, wait for more events to arrive.
		while _playing and gen == _playback_gen and !event_player.has_next():
			var log := event_player._log # or add a getter; see note below
			if log == null:
				_playing = false
				return
			await log.appended
			await get_tree().process_frame
		
		if !_playing or gen != _playback_gen:
			return
		
		var beat := event_player.next_beat()
		if beat.is_empty():
			#await get_tree().process_frame
			continue
			
		print("battle_view.gd _playback_loop() this beat contains : v")
		for event: BattleEvent in beat:
			print("battle_view.gd _playback_loop() ", BattleEvent.Type.keys()[event.type])
		print("battle_view.gd _playback_loop() this beat contained: ^")
		
		var note_denom := _note_for_beat(beat)
		var duration := transport.get_beat_duration(note_denom)
		
		var pkg := BeatPackage.new()
		pkg.beat = beat
		pkg.gen = gen
		pkg.duration = duration
		
		event_director.play_beat(pkg)
		
		if !_playing or gen != _playback_gen:
			return
		if duration > 0.0:
			await get_tree().create_timer(duration).timeout

func get_or_create_combatant_view(cid: int, group_index: int, insert_index: int) -> CombatantView:
	if cid <= 0:
		return null
	if combatants_by_cid.has(cid):
		return combatants_by_cid[cid]
	
	var combatant := combatant_view_scene.instantiate() as CombatantView
	if combatant == null:
		push_error("BattleView: combatant_view_scene must instance a CombatantView")
		return null
	
	var group : GroupView = friendly_group if group_index == 0 else enemy_group
	group.add_child(combatant)
	
	#var cv := combatant as CombatantView
	combatant.cid = cid
	#cv.bind_assets(_assets)
	
	# Optional insert
	var n_children := group.get_child_count()
	if insert_index < 0:
		insert_index = n_children - 1
	insert_index = clampi(insert_index, 0, n_children - 1)
	group.move_child(combatant, insert_index)
	
	combatants_by_cid[cid] = combatant
	group.register_view(combatant) # triggers layout
	return combatant

func set_group_order(group_index: int, order: Array) -> void:
	var group : GroupView = friendly_group if group_index == 0 else enemy_group
	group.set_order(order)

func get_combatant(cid: int) -> CombatantView:
	return combatants_by_cid.get(cid, null)

func get_combatants() -> Array[CombatantView]:
	var combatants : Array[CombatantView] = []
	for key in combatants_by_cid:
		combatants.push_back(combatants_by_cid[key] as CombatantView)
	return combatants

func _note_for_beat(beat: Array[BattleEvent]) -> float:
	print("battle_view.gd _gap_for_beat()")
	if beat.is_empty():
		return 0.0
	
	# find the beat marker inside this beat (usually first non-scope you appended)
	var marker: BattleEvent = null
	for e in beat:
		if e != null and e.defines_beat:
			marker = e
			break
	if marker == null:
		return 0.0
	
	# defaults by type (for now)
	match int(marker.type):
		BattleEvent.Type.ARCANUM_PREP:
			return 4.0
		BattleEvent.Type.ARCANUM_WRAPUP:
			return 4.0
		BattleEvent.Type.ATTACK_PREP:
			return 4.0
		BattleEvent.Type.STRIKE_WINDUP:
			return 4.0
		BattleEvent.Type.STRIKE_FOLLOWTHROUGH:
			return 4.0
		BattleEvent.Type.ATTACK_WRAPUP:
			return 4.0
		_:
			return 0.0

func apply_focus(order: FocusOrder) -> void:
	_apply_focus_background(order)
	_apply_focus_combatants(order)

func clear_focus(duration: float) -> void:
	for combatant: CombatantView in get_combatants():
		combatant.clear_focus(duration)
	var bg: Array[Node] = get_tree().get_nodes_in_group("background")
	for item in bg:
		if item.has_method("modulate"):
			var tween = item.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.tween_property(item, "modulate", Color(1, 1, 1, 1.0), duration)

func _apply_focus_background(order: FocusOrder) -> void:
	print("battle_view.gd _apply_focus_background() 1")
	var bg = get_tree().get_nodes_in_group("background")
	for item in bg:
		print("battle_view.gd _apply_focus_background() 2")
		if "modulate" in item:
			print("battle_view.gd _apply_focus_background() 3")
			var tween = item.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(item, "modulate", Color(order.dim_bg, order.dim_bg, order.dim_bg, 1.0), order.duration)

func _apply_focus_combatants(order: FocusOrder) -> void:
	for combatant: CombatantView in get_combatants():
		combatant.on_focus(order)
