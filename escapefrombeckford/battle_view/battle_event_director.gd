# battle_event_director.gd

class_name BattleEventDirector extends RefCounted

var _view: BattleView

func bind(view: BattleView) -> void:
	_view = view

func on_event(e: BattleEvent) -> void:
	if e == null or _view == null:
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
		BattleEvent.Type.SCOPE_BEGIN:
			_on_scope_begin(e)
		BattleEvent.Type.SCOPE_END:
			_on_scope_end(e)
		_:
			# ignore for now
			pass

func _on_spawned(e: BattleEvent) -> void:
	var cid := int(e.data.get(&"spawned_id", 0))
	var g := int(e.data.get(Keys.GROUP_INDEX, e.group_index))
	var idx := int(e.data.get(Keys.INSERT_INDEX, -1))

	var v := _view.get_or_create_combatant_view(cid, g, idx)
	if v == null:
		return

	var spec: Dictionary = e.data.get(Keys.SUMMON_SPEC, {})
	# You’re using SPAWNED spec key &"spec"; keep flexible:
	if e.data.has(&"spec"):
		spec = e.data[&"spec"]

	v.apply_spawn_spec(spec)

func _on_summoned(e: BattleEvent) -> void:
	var cid := int(e.data.get(Keys.SUMMONED_ID, 0))
	var g := int(e.data.get(Keys.GROUP_INDEX, e.group_index))
	var idx := int(e.data.get(Keys.INSERT_INDEX, -1))

	var v := _view.get_or_create_combatant_view(cid, g, idx)
	if v == null:
		return

	var spec: Dictionary = e.data.get(Keys.SUMMON_SPEC, {})
	v.apply_spawn_spec(spec)
	v.play_summon_fx()

func _on_formation_set(e: BattleEvent) -> void:
	# Your payload: {player_id, group_0, group_1}
	var g0: Array = e.data.get(&"group_0", [])
	var g1: Array = e.data.get(&"group_1", [])

	_view.set_group_order(0, g0)
	_view.set_group_order(1, g1)

func _on_moved(e: BattleEvent) -> void:
	# Current moved event stores before/after orders.
	var after_ids := e.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
	var g := int(e.group_index)
	if after_ids is PackedInt32Array:
		var arr: Array = []
		arr.resize(after_ids.size())
		for i in range(after_ids.size()):
			arr[i] = int(after_ids[i])
		_view.set_group_order(g, arr)

func _on_targeted(e: BattleEvent) -> void:
	var src := int(e.data.get(Keys.SOURCE_ID, 0))
	var targets: Array = e.data.get(Keys.TARGET_IDS, [])
	var src_view := _view.get_view(src)
	if src_view != null:
		src_view.play_targeting()

	for tid in targets:
		var tv := _view.get_view(int(tid))
		if tv != null:
			tv.show_targeted(true)

func _on_damage_applied(e: BattleEvent) -> void:
	var src := int(e.data.get(Keys.SOURCE_ID, 0))
	var tid := int(e.data.get(Keys.TARGET_ID, 0))
	var amount := int(e.data.get(Keys.FINAL_AMOUNT, 0))

	var target_view := _view.get_view(tid)
	if target_view != null:
		target_view.play_hit()
		target_view.pop_damage_number(amount)

	var src_view := _view.get_view(src)
	if src_view != null:
		src_view.play_attack_react()

func _on_status_applied(e: BattleEvent) -> void:
	var tid := int(e.data.get(Keys.TARGET_ID, 0))
	var status_id := e.data.get(Keys.STATUS_ID, &"")
	var tv := _view.get_view(tid)
	if tv != null:
		tv.add_status_icon(status_id)

func _on_status_removed(e: BattleEvent) -> void:
	var tid := int(e.data.get(Keys.TARGET_ID, 0))
	var status_id := e.data.get(Keys.STATUS_ID, &"")
	var tv := _view.get_view(tid)
	if tv != null:
		tv.remove_status_icon(status_id)

func _on_scope_begin(_e: BattleEvent) -> void:
	# Later: update “phase title”, camera focus, etc.
	pass

func _on_scope_end(_e: BattleEvent) -> void:
	pass
