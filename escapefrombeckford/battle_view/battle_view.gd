# battle_view.gd

class_name BattleView extends Node2D

@onready var combatant_view_scene: PackedScene = preload("res://battle_view/combatant_view.tscn")

@onready var friendly_group: GroupView = $Group0
@onready var enemy_group: GroupView = $Group1

var sim_host: SimHost
var battle_ui: BattleUI

var event_player: BattleEventPlayer
var event_director: BattleEventDirector
#var _assets := BattleAssetCache.new()

var _playing := false
var _playback_gen: int = 0

var combatants_by_cid: Dictionary = {}

# Playback knobs
@export var playback_scale: float = 1.0
@export var beat_gap_sec: float = 0.12
@export var scope_gap_sec: float = 0.20

func _ready() -> void:
	event_player = BattleEventPlayer.new()
	event_director = BattleEventDirector.new()
	event_director.bind(self)

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
			await get_tree().process_frame
			continue
		
		await event_director.play_beat_async(beat, gen)
		
		if !_playing or gen != _playback_gen:
			return
		
		var gap := _gap_for_beat(beat)
		if gap > 0.0:
			await get_tree().create_timer(gap).timeout
		
		await get_tree().process_frame

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

func _gap_for_beat(beat: Array[BattleEvent]) -> float:
	if beat.is_empty():
		return 0.0
	print("battle_view.gd _gap_for_beat() beat contains the following: ")
	for event: BattleEvent in beat:
		print("battle_view.gd _gap_for_beat() scope kind: %s, event type: %s" % [Scope.Kind.keys()[event.scope_kind] , BattleEvent.Type.keys()[event.type]])
	# Root is usually SCOPE_BEGIN for scoped beats.
	var root := beat[0]
	var root_type := int(root.type)
	
	# Baseline: give scopes a little more breathing room than single events.
	var gap := scope_gap_sec if root_type == BattleEvent.Type.SCOPE_BEGIN else beat_gap_sec
	
	# If we can read the root scope kind, use it as a pacing hint.
	# (You set e.scope_kind on every event in writer; root should have it.)
	var kind := int(root.scope_kind)
	
	match kind:
		Scope.Kind.BATTLE:
			gap = 0.0
		Scope.Kind.SETUP:
			# Setup can be snappy; it's mostly visuals appearing.
			gap = min(gap, 0.10)
		Scope.Kind.GROUP_TURN:
			gap = max(gap, 0.18)
		Scope.Kind.ACTOR_TURN:
			gap = max(gap, 0.22)
		Scope.Kind.ARCANA:
			gap = max(gap, 0.20)
		Scope.Kind.ARCANUM:
			gap = max(gap, 0.24)
		Scope.Kind.CARD:
			gap = max(gap, 0.22)
		Scope.Kind.ATTACK, Scope.Kind.STRIKE, Scope.Kind.HIT, Scope.Kind.DAMAGE:
			gap = max(gap, 0.16)
		_:
			pass
	
	# Now scan for specific "read me" events inside the beat and bump the delay.
	# This lets you pace unscoped beats too.
	var saw_summon := false
	var saw_damage := false
	var saw_death := false
	var saw_move := false
	var saw_card := false
	
	for e in beat:
		match int(e.type):
			BattleEvent.Type.SUMMONED, BattleEvent.Type.SPAWNED:
				saw_summon = true
			BattleEvent.Type.DAMAGE_APPLIED:
				saw_damage = true
			BattleEvent.Type.DIED:
				saw_death = true
			BattleEvent.Type.MOVED, BattleEvent.Type.FORMATION_SET:
				saw_move = true
			BattleEvent.Type.CARD_PLAYED:
				saw_card = true
			_:
				pass
	
	if saw_death:
		gap = max(gap, 0.35)
	elif saw_summon:
		gap = max(gap, 0.28)
	elif saw_card:
		gap = max(gap, 0.24)
	elif saw_damage:
		# Damage often happens in clusters; keep it readable but not sluggish.
		gap = max(gap, 0.16)
	elif saw_move:
		gap = max(gap, 0.18)
	
	# Optional: cap so it never feels like it stalls.
	print("battle_view.gd _gap_for_beat() gap: ", gap)
	var gap_time: float = min(gap, 1.0)*playback_scale
	print("battle_view.gd _gap_for_beat() scaled gap: ", gap_time)
	return gap_time
