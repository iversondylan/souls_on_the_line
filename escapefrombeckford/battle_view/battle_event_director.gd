# battle_event_director.gd

class_name BattleEventDirector extends RefCounted

var battle_view: BattleView


@export var spawn_pause_sec: float = 0.04
@export var summon_pause_sec: float = 0.06
@export var hit_pause_sec: float = 0.05

func bind(new_battle_view: BattleView) -> void:
	battle_view = new_battle_view

func play_beat_async(beat: Array[BattleEvent], gen: int) -> void:
	if battle_view == null or beat.is_empty():
		return
	
	for e in beat:
		# cancellation check
		if !battle_view._playing or gen != battle_view._playback_gen:
			return
		
		on_event(e)

func on_event(e: BattleEvent) -> void:
	if e == null or battle_view == null:
		return
	
	match int(e.type):
		BattleEvent.Type.SPAWNED:
			_on_spawned(e)
		BattleEvent.Type.SUMMONED:
			_on_summoned(e)
		BattleEvent.Type.FORMATION_SET:
			_on_formation_set(e)
		BattleEvent.Type.MOVED:
			_on_moved(e)
		BattleEvent.Type.TARGETED:
			_on_targeted(e)
		BattleEvent.Type.DAMAGE_APPLIED:
			_on_damage_applied(e)
		BattleEvent.Type.STATUS_APPLIED:
			_on_status_applied(e)
		BattleEvent.Type.STATUS_REMOVED:
			_on_status_removed(e)
		BattleEvent.Type.DIED:
			_on_died(e)
		BattleEvent.Type.SCOPE_BEGIN:
			_on_scope_begin(e)
		BattleEvent.Type.SCOPE_END:
			_on_scope_end(e)
		_:
			# ignore for now
			pass

func _on_spawned(e: BattleEvent) -> void:
	var cid := int(e.data.get(Keys.SPAWNED_ID, 0))
	var g := int(e.data.get(Keys.GROUP_INDEX, e.group_index))
	var idx := int(e.data.get(Keys.INSERT_INDEX, -1))
	var after_ids : PackedInt32Array = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
	#print("battle_event_director.gd _on_spawned() cid: %s, group: %s, ind: %s" % [cid, g, idx])
	var v := battle_view.get_or_create_combatant_view(cid, g, idx)
	if v == null:
		return
	
	var spec: Dictionary = e.data.get(Keys.SUMMON_SPEC, {})
	
	v.apply_spawn_spec(spec)
	battle_view.set_group_order(g, after_ids)

func _on_summoned(e: BattleEvent) -> void:
	
	var cid := int(e.data.get(Keys.SUMMONED_ID, 0))
	var g := int(e.data.get(Keys.GROUP_INDEX, e.group_index))
	var idx := int(e.data.get(Keys.INSERT_INDEX, -1))
	var after_ids : PackedInt32Array = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
	#print("battle_event_director.gd _on_summoned() cid: %s, group: %s, ind: %s" % [cid, g, idx])
	var combatant := battle_view.get_or_create_combatant_view(cid, g, idx)
	if combatant == null:
		return
	
	var spec: Dictionary = e.data.get(Keys.SUMMON_SPEC, {})
	combatant.apply_spawn_spec(spec)
	combatant.play_summon_fx()
	battle_view.set_group_order(g, after_ids)

func _on_formation_set(e: BattleEvent) -> void:
	# Your payload: {player_id, group_0, group_1}
	var g0: Array = e.data.get(Keys.GROUP_0, [])
	var g1: Array = e.data.get(Keys.GROUP_1, [])
	#print("battle_event_director.gd _on_formation_set() g0: %s, g1: %s" % [g0, g1])
	battle_view.set_group_order(0, g0)
	battle_view.set_group_order(1, g1)

func _on_moved(e: BattleEvent) -> void:
	# Current moved event stores before/after orders.
	var after_ids : PackedInt32Array = e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
	var g := int(e.group_index)
	#print("battle_event_director.gd _on_moved() after_ids: %s, g: %s" % [after_ids, g])
	if after_ids is PackedInt32Array:
		var arr: Array = []
		arr.resize(after_ids.size())
		for i in range(after_ids.size()):
			arr[i] = int(after_ids[i])
		battle_view.set_group_order(g, arr)

func _on_targeted(e: BattleEvent) -> void:
	var src := int(e.data.get(Keys.SOURCE_ID, 0))
	var targets: Array = e.data.get(Keys.TARGET_IDS, [])
	var combatant := battle_view.get_combatant(src)
	#print("battle_event_director.gd _on_targeted() src: %s, targets: %s" % [src, targets])
	if combatant != null:
		combatant.play_targeting()
	
	for tid in targets:
		var tv := battle_view.get_combatant(int(tid))
		if tv != null:
			tv.show_targeted(true)

func _on_damage_applied(e: BattleEvent) -> void:
	var src := int(e.data.get(Keys.SOURCE_ID, 0))
	var tid := int(e.data.get(Keys.TARGET_ID, 0))
	var amount := int(e.data.get(Keys.FINAL_AMOUNT, 0))
	var lethal := bool(e.data.get(Keys.WAS_LETHAL, false))
	var target_combatant := battle_view.get_combatant(tid)
	var after_health := int(e.data.get(Keys.AFTER_HEALTH, 1))
	#print("battle_event_director.gd _on_damage_applied() src: %s, tid: %s, amount: %s" % [src, tid, amount])
	if target_combatant != null:
		target_combatant.play_hit()
		target_combatant.set_health(after_health, lethal)
		target_combatant.pop_damage_number(amount)

func _on_status_applied(e: BattleEvent) -> void:
	var tid := int(e.data.get(Keys.TARGET_ID, 0))
	var status_id : StringName = e.data.get(Keys.STATUS_ID, &"")
	var target_combatant := battle_view.get_combatant(tid)
	#print("battle_event_director.gd _on_status_applied() tid: %s, status_id: %s" % [tid, status_id])
	if target_combatant != null:
		target_combatant.add_status_icon(status_id)

func _on_status_removed(e: BattleEvent) -> void:
	var tid := int(e.data.get(Keys.TARGET_ID, 0))
	var status_id : StringName = e.data.get(Keys.STATUS_ID, &"")
	var target_combatant := battle_view.get_combatant(tid)
	#print("battle_event_director.gd _on_status_removed() tid: %s, status_id: %s" % [tid, status_id])
	if target_combatant != null:
		target_combatant.remove_status_icon(status_id)

func _on_died(e: BattleEvent) -> void:
	pass

func _on_scope_begin(_e: BattleEvent) -> void:
	#print("battle_event_director.gd _on_scope_begin()")
	# Later: update “phase title”, camera focus, etc.
	pass

func _on_scope_end(_e: BattleEvent) -> void:
	#print("battle_event_director.gd _on_scope_end()")
	pass

func play_beat(beat: Array[BattleEvent]) -> void:
	if battle_view == null or beat.is_empty():
		return

	for e in beat:
		on_event(e)
