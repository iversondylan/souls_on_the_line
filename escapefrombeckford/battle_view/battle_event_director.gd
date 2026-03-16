# battle_event_director.gd

class_name BattleEventDirector extends RefCounted

var battle_view: BattleView
var click: Sound

@export var spawn_pause_sec: float = 0.04
@export var summon_pause_sec: float = 0.06
@export var hit_pause_sec: float = 0.05


# ------------------------------------------------------------------------------
# Entry points
# ------------------------------------------------------------------------------

func bind(new_battle_view: BattleView) -> void:
	battle_view = new_battle_view
	click = battle_view.click_sound


func on_director_action(a: DirectorAction, gen: int) -> void:
	if a == null or battle_view == null:
		return
	if !battle_view._playing or gen != battle_view._playback_gen:
		return

	match a.phase:
		DirectorAction.Phase.FOCUS:
			_play_focus_action(a)
		DirectorAction.Phase.WINDUP:
			_play_windup_action(a)
		DirectorAction.Phase.FOLLOWTHROUGH:
			_play_followthrough_action(a)
		DirectorAction.Phase.RESOLVE:
			_play_resolve_action(a)


func play_raw_chunk(pkg: BeatPackage) -> void:
	if pkg == null or pkg.beat.is_empty():
		return
	if battle_view == null:
		return
	if !battle_view._playing or pkg.gen != battle_view._playback_gen:
		return

	if pkg.wait_quarters > 0.0:
		SFXPlayer.play(click)

	for be in pkg.beat:
		if be == null:
			continue
		on_event(_make_epkg_from_event(be, pkg.duration_sec))


func on_event(e: EventPackage) -> void:
	if e == null or e.event == null or battle_view == null:
		return

	match int(e.event.type):
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
		BattleEvent.Type.STATUS, BattleEvent.Type.STATUS_CHANGED:
			_on_status_changed(e)
		BattleEvent.Type.DIED:
			_on_died(e)
		BattleEvent.Type.SET_INTENT:
			_on_set_intent(e)
		BattleEvent.Type.SCOPE_BEGIN:
			_on_scope_begin(e)
		BattleEvent.Type.SCOPE_END:
			_on_scope_end(e)
		BattleEvent.Type.TURN_STATUS:
			_on_turn_status(e)
		BattleEvent.Type.PLAYER_INPUT_REACHED:
			Events.request_draw_hand.emit()
		BattleEvent.Type.END_TURN_PRESSED:
			Events.player_turn_completed.emit()
		BattleEvent.Type.DISCARD_REQUESTED:
			_on_discard_requested(e)
		BattleEvent.Type.FADED:
			_on_faded(e)
		BattleEvent.Type.SUMMON_RESERVE_RELEASED:
			_on_summon_reserve_released(e)
		_:
			pass


# ------------------------------------------------------------------------------
# Director phase playback
# ------------------------------------------------------------------------------

func _play_focus_action(a: DirectorAction) -> void:
	if a == null:
		return

	var attack_info := _as_attack_info(a)
	if attack_info != null:
		_on_attack_prep_from_info(attack_info, a.duration_sec)
		return

	var action_timeline := _as_action_timeline(a)
	if action_timeline != null:
		_on_action_focus_from_timeline(action_timeline, a.duration_sec)
		return

	if a.event != null:
		_on_action_focus(_make_epkg_from_event(a.event, a.duration_sec))


func _play_windup_action(a: DirectorAction) -> void:
	if a == null:
		return

	var attack_info := _as_attack_info(a)
	if attack_info != null:
		_on_strike_windup_from_info(attack_info, a.duration_sec)
		return

	var action_timeline := _as_action_timeline(a)
	if action_timeline != null:
		_on_action_windup_from_timeline(action_timeline, a.duration_sec)
		return

	if a.event != null:
		_on_action_focus(_make_epkg_from_event(a.event, a.duration_sec))


func _play_followthrough_action(a: DirectorAction) -> void:
	if a == null:
		return

	var attack_info := _as_attack_info(a)
	if attack_info != null:
		_on_strike_followthrough_from_info(attack_info, a.duration_sec)

		# Only non-structural, non-delete raw events here
		_apply_payload_events(
			a.payload,
			a.duration_sec,
			{
				BattleEvent.Type.DAMAGE_APPLIED: true,
				BattleEvent.Type.STATUS: true,
				BattleEvent.Type.SUMMONED: true,
			}
		)
		return

	var action_timeline := _as_action_timeline(a)
	if action_timeline != null:
		_on_action_followthrough_from_timeline(action_timeline, a.duration_sec)
		_apply_payload_events(
			a.payload,
			a.duration_sec,
			{
				BattleEvent.Type.DAMAGE_APPLIED: true,
				BattleEvent.Type.STATUS: true,
				BattleEvent.Type.SUMMONED: true,
			}
		)
		return

	_apply_payload_events(
		a.payload,
		a.duration_sec,
		{
			BattleEvent.Type.DAMAGE_APPLIED: true,
			BattleEvent.Type.STATUS: true,
			BattleEvent.Type.SUMMONED: true,
		}
	)


func _play_resolve_action(a: DirectorAction) -> void:
	if a == null:
		return

	# Structural / board-state events belong here
	_apply_payload_events(
		a.payload,
		a.duration_sec,
		{
			BattleEvent.Type.DIED: true,
			BattleEvent.Type.FADED: true,
			BattleEvent.Type.STATUS: true,
			BattleEvent.Type.SET_INTENT: true,
			BattleEvent.Type.TURN_STATUS: true,
			BattleEvent.Type.MOVED: true,
		}
	)

	_relayout_groups_after_resolve()

	var attack_info := _as_attack_info(a)
	if attack_info != null:
		_on_attack_wrapup_from_info(attack_info, a.duration_sec)
		return

	battle_view.clear_focus(a.duration_sec)


# ------------------------------------------------------------------------------
# Shared event/data helpers
# ------------------------------------------------------------------------------

func _as_attack_info(a: DirectorAction) -> AttackPresentationInfo:
	if a == null:
		return null
	return a.presentation as AttackPresentationInfo


func _as_action_timeline(a: DirectorAction) -> ActionTimelinePresentationInfo:
	if a == null:
		return null
	return a.presentation as ActionTimelinePresentationInfo


func _make_epkg_from_event(event: BattleEvent, duration: float) -> EventPackage:
	var epkg := EventPackage.new()
	epkg.event = event
	epkg.duration = duration
	return epkg


func _data(e: EventPackage) -> Dictionary:
	return e.event.data if e != null and e.event != null and e.event.data != null else {}


func _source_id(e: EventPackage) -> int:
	var d := _data(e)
	return int(d.get(Keys.SOURCE_ID, d.get(Keys.ACTOR_ID, 0)))


func _target_id(e: EventPackage) -> int:
	return int(_data(e).get(Keys.TARGET_ID, 0))


func _target_ids(e: EventPackage) -> Array[int]:
	var d := _data(e)
	var out := _coerce_int_array(d.get(Keys.TARGET_IDS, []))
	if out.is_empty():
		var tid := int(d.get(Keys.TARGET_ID, 0))
		if tid > 0:
			out.append(tid)
	return out


func _group_index(e: EventPackage) -> int:
	var d := _data(e)
	return int(d.get(Keys.GROUP_INDEX, e.event.group_index))


func _after_order(e: EventPackage) -> Array[int]:
	return _packed_to_int_array(_data(e).get(Keys.AFTER_ORDER_IDS, PackedInt32Array()))


func _before_order(e: EventPackage) -> Array[int]:
	return _packed_to_int_array(_data(e).get(Keys.BEFORE_ORDER_IDS, PackedInt32Array()))


func _packed_to_int_array(value) -> Array[int]:
	var out: Array[int] = []

	if value is PackedInt32Array:
		for x in value:
			out.append(int(x))
	elif value is Array:
		for x in value:
			out.append(int(x))

	return out


func _coerce_int_array(value) -> Array[int]:
	var out: Array[int] = []

	if value is PackedInt32Array:
		for x in value:
			out.append(int(x))
		return out

	if value is Array:
		for x in value:
			out.append(int(x))
		return out

	return out


func _make_focus_order(attacker_id: int, target_ids: Array[int], duration: float) -> FocusOrder:
	var order := FocusOrder.new()
	order.duration = duration
	order.attacker_id = attacker_id
	order.target_ids = target_ids
	order.dim_bg = 0.6
	order.dim_uninvolved = 0.55
	order.scale_involved = 1.08
	order.scale_uninvolved = 1.0
	order.drift_involved = 20.0
	return order


func _apply_group_order(group_index: int, order_ids: Array[int], animate: bool) -> void:
	if order_ids.is_empty():
		return

	var ctx := GroupLayoutOrder.new()
	ctx.group_index = group_index
	ctx.order = order_ids
	ctx.animate_to_position = animate
	battle_view.set_group_order(ctx)


func _apply_payload_events(payload: Array, duration: float, allowed_types: Dictionary = {}) -> void:
	if payload == null or payload.is_empty():
		return

	for e in payload:
		var be := e as BattleEvent
		if be == null:
			continue
		if !allowed_types.is_empty() and !allowed_types.has(int(be.type)):
			continue
		on_event(_make_epkg_from_event(be, duration))


func _make_status_applied_order(e: EventPackage) -> StatusAppliedOrder:
	var d := _data(e)

	var o := StatusAppliedOrder.new()
	o.duration = e.duration
	o.source_id = int(d.get(Keys.SOURCE_ID, 0))
	o.target_id = int(d.get(Keys.TARGET_ID, 0))
	o.status_id = d.get(Keys.STATUS_ID, &"")
	o.intensity = int(d.get(Keys.AFTER_INTENSITY, d.get(Keys.INTENSITY, 1)))
	o.turns_duration = int(d.get(Keys.AFTER_DURATION, d.get(Keys.DURATION, 0)))

	return o


func _make_status_removed_order(e: EventPackage) -> StatusRemovedOrder:
	var d := _data(e)

	var o := StatusRemovedOrder.new()
	o.duration = e.duration
	o.source_id = int(d.get(Keys.SOURCE_ID, 0))
	o.target_id = int(d.get(Keys.TARGET_ID, 0))
	o.status_id = d.get(Keys.STATUS_ID, &"")
	o.intensity = int(d.get(Keys.INTENSITY, 1))
	o.removed_all = true

	return o

func _relayout_groups_after_resolve() -> void:
	if battle_view == null:
		return

	if battle_view.friendly_group != null:
		battle_view.friendly_group.relayout_alive_immediate(true)

	if battle_view.enemy_group != null:
		battle_view.enemy_group.relayout_alive_immediate(true)

# ------------------------------------------------------------------------------
# Raw event handlers
# ------------------------------------------------------------------------------

func _on_spawned(e: EventPackage) -> void:
	var d := _data(e)
	var cid := int(d.get(Keys.SPAWNED_ID, 0))
	var g := _group_index(e)
	var idx := int(d.get(Keys.INSERT_INDEX, -1))
	var is_player := bool(d.get(Keys.IS_PLAYER, false))

	var v := battle_view.get_or_create_combatant_view(cid, g, idx, false, is_player)
	if v == null:
		return

	v.apply_spawn_spec(d.get(Keys.SUMMON_SPEC, {}))
	_apply_group_order(g, _after_order(e), false)


func _on_turn_status(e: EventPackage) -> void:
	var d := _data(e)
	var active_id := int(d.get(Keys.ACTIVE_ID, 0))
	var pending_ids: PackedInt32Array = d.get(Keys.PENDING_IDS, PackedInt32Array())

	var pending_set := {}
	for cid in pending_ids:
		pending_set[int(cid)] = true

	for v: CombatantView in battle_view.get_all_combatant_views():
		if v == null or !is_instance_valid(v):
			continue

		if !v.is_alive:
			v.set_pending_turn_glow(CombatantView.TurnStatus.NONE)
			continue

		if int(v.cid) == active_id:
			v.set_pending_turn_glow(CombatantView.TurnStatus.TURN_ACTIVE)
		elif pending_set.has(int(v.cid)):
			v.set_pending_turn_glow(CombatantView.TurnStatus.TURN_PENDING)
		else:
			v.set_pending_turn_glow(CombatantView.TurnStatus.NONE)


func _on_formation_set(e: EventPackage) -> void:
	var d := _data(e)
	_apply_group_order(0, _coerce_int_array(d.get(Keys.GROUP_0, [])), false)
	_apply_group_order(1, _coerce_int_array(d.get(Keys.GROUP_1, [])), false)


func _on_action_focus(e: EventPackage) -> void:
	if e == null or e.event == null:
		return

	battle_view.apply_focus(
		_make_focus_order(_source_id(e), _target_ids(e), e.duration)
	)


func _on_attack_prep(e: EventPackage) -> void:
	if e == null or e.event == null:
		return

	battle_view.apply_focus(
		_make_focus_order(_source_id(e), _target_ids(e), e.duration)
	)


func _on_attack_wrapup(e: EventPackage) -> void:
	battle_view.clear_focus(e.duration)

	var attacker := battle_view.get_combatant(_source_id(e))
	if attacker != null:
		attacker.clear_strike_pose(e.duration)

	if int(_data(e).get(Keys.ATTACK_MODE, Attack.Mode.MELEE)) == int(Attack.Mode.RANGED):
		var strike_count := int(_data(e).get(Keys.STRIKE_COUNT, 1))
		for i in range(strike_count):
			var key := int(battle_view.make_projectile_key(_source_id(e), i))
			var projectile := battle_view.take_projectile(key)
			if projectile != null and is_instance_valid(projectile):
				projectile.queue_free()


func _on_strike_windup(e: EventPackage) -> void:
	var attacker := battle_view.get_combatant(_source_id(e))
	if attacker == null:
		return

	var d := _data(e)
	var o := StrikeWindupOrder.new()
	o.duration = e.duration
	o.attacker_id = _source_id(e)
	o.target_ids = _target_ids(e)
	o.attack_mode = int(d.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	o.projectile_scene_path = String(d.get(Keys.PROJECTILE_SCENE, "res://VFX/projectiles/fireball/fireball.tscn"))
	o.strike_count = int(d.get(Keys.STRIKE_COUNT, 1))

	attacker.play_strike_windup(o, battle_view)


func _on_strike_followthrough(e: EventPackage) -> void:
	var attacker := battle_view.get_combatant(_source_id(e))
	if attacker == null:
		return

	var d := _data(e)
	var o := StrikeFollowthroughOrder.new()
	o.duration = e.duration
	o.attacker_id = _source_id(e)
	o.target_ids = _target_ids(e)
	o.attack_mode = int(d.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	o.strike_count = int(d.get(Keys.STRIKE_COUNT, 1))
	o.total_hit_count = int(d.get(Keys.TOTAL_HIT_COUNT, 1))
	o.has_lethal_hit = bool(d.get(Keys.HAS_LETHAL_HIT, false))

	attacker.play_strike_followthrough(o, battle_view)


func _on_moved(e: EventPackage) -> void:
	_apply_group_order(int(e.event.group_index), _after_order(e), true)


func _on_targeted(e: EventPackage) -> void:
	var combatant := battle_view.get_combatant(_source_id(e))
	if combatant != null:
		combatant.play_targeting()

	for tid in _target_ids(e):
		var tv := battle_view.get_combatant(int(tid))
		if tv != null:
			tv.show_targeted(true)


func _on_damage_applied(e: EventPackage) -> void:
	var d := _data(e)
	var tid := int(d.get(Keys.TARGET_ID, 0))
	var amount := int(d.get(Keys.FINAL_AMOUNT, 0))
	var lethal := bool(d.get(Keys.WAS_LETHAL, false))
	var after_health := int(d.get(Keys.AFTER_HEALTH, 1))
	var target_combatant := battle_view.get_combatant(tid)

	if target_combatant != null:
		target_combatant.play_hit()
		target_combatant.set_health(after_health, lethal)
		target_combatant.pop_damage_number(amount)


func _on_status_changed(e: EventPackage) -> void:
	if e == null or e.event == null:
		return

	var d := _data(e)
	var op := int(d.get(Keys.OP, 0))
	var target := battle_view.get_combatant(int(d.get(Keys.TARGET_ID, 0)))
	if target == null or target.status_view_grid == null:
		return

	if op == int(Status.OP.REMOVE):
		target.status_view_grid.remove_status(_make_status_removed_order(e))
		return

	target.status_view_grid.apply_status(_make_status_applied_order(e))


func _on_set_intent(e: EventPackage) -> void:
	var d := _data(e)
	var cid := int(d.get(Keys.ACTOR_ID, e.event.active_actor_id))
	var planned_idx := int(d.get(Keys.PLANNED_IDX, -1))
	var icon_uid := String(d.get(Keys.INTENT_ICON_UID, ""))
	var icon_ranged_uid := String(d.get(Keys.INTENT_ICON_RANGED_UID, ""))
	var intent_text := String(d.get(Keys.INTENT_TEXT, ""))
	var tooltip_text := String(d.get(Keys.TOOLTIP_TEXT, ""))
	var is_ranged := bool(d.get(Keys.IS_RANGED, false))

	var cv := battle_view.get_combatant(cid)
	if cv == null:
		return

	if cv.intent_container != null:
		cv.intent_container.apply_intent(planned_idx, icon_uid, icon_ranged_uid, is_ranged, intent_text, tooltip_text)


func _on_died(e: EventPackage) -> void:
	var dead_id := _target_id(e)
	if dead_id <= 0:
		return

	var v := battle_view.get_combatant(dead_id)
	if v != null:
		v.queue_free()

	battle_view.combatants_by_cid.erase(dead_id)


func _on_death_windup(e: EventPackage) -> void:
	var dead_id := _target_id(e)
	if dead_id <= 0:
		return

	var target := battle_view.get_combatant(dead_id)
	if target == null:
		return

	var o := DeathWindupOrder.new()
	o.duration = e.duration
	o.dead_id = dead_id
	o.to_black = true
	o.black_amount = 1.0
	o.shrink = 0.96
	o.slump_px = 10.0

	target.play_death_windup(o)


func _on_death_followthrough(e: EventPackage) -> void:
	var dead_id := _target_id(e)
	var g := _group_index(e)

	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)

	var dead_view := battle_view.get_combatant(dead_id)
	if dead_view != null:
		dead_view.on_death_followthrough(e.duration)

	_apply_group_order(g, _after_order(e), true)


func _on_discard_requested(e: EventPackage) -> void:
	if e == null:
		return

	var d: Dictionary = _data(e)
	var ctx := DiscardContext.new()
	ctx.source_id = int(d.get(Keys.SOURCE_ID, 0))
	ctx.amount = int(d.get(Keys.AMOUNT, 0))
	ctx.card_uid = String(d.get(Keys.CARD_UID, ""))

	var sim_host: SimHost = battle_view.sim_host if battle_view != null else null
	ctx.on_done = func(chosen_uids: Array[String]) -> void:
		if sim_host == null:
			push_warning("DiscardContext.on_done: missing sim_host")
			return
		var api := sim_host.get_main_api()
		if api == null:
			push_warning("DiscardContext.on_done: missing sim api")
			return
		api.resolve_player_discard(chosen_uids)

	Events.request_discard_cards.emit(ctx)


func _on_fade_windup(e: EventPackage) -> void:
	var v := battle_view.get_combatant(_target_id(e))
	if v == null or v.character_art == null:
		return

	if v.tween_misc:
		v.tween_misc.kill()
	v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	v.tween_misc.tween_property(v.character_art, "modulate:a", 0.0, maxf(e.duration, 0.01))


func _on_fade_followthrough(e: EventPackage) -> void:
	var dead_id := _target_id(e)
	var g := _group_index(e)

	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)

	var dv := battle_view.get_combatant(dead_id)
	if dv != null:
		dv.is_alive = false

	_apply_group_order(g, _after_order(e), true)


func _on_faded(e: EventPackage) -> void:
	var dead_id := _target_id(e)

	var v := battle_view.get_combatant(dead_id)
	if v != null:
		v.queue_free()

	battle_view.combatants_by_cid.erase(dead_id)


func _on_summon_windup(e: EventPackage) -> void:
	var v := _ensure_summon_view(e, false)
	if v == null:
		return

	_place_summon_for_windup(e, v)


func _on_summon_followthrough(e: EventPackage) -> void:
	var summoned_id := int(_data(e).get(Keys.SUMMONED_ID, 0))
	var g := _group_index(e)

	var v := battle_view.get_combatant(summoned_id)
	if v != null:
		v.is_alive = true

	_apply_group_order(g, _after_order(e), true)


func _on_summoned(e: EventPackage) -> void:
	var v := _ensure_summon_view(e, true)
	if v == null:
		return

	if v.character_art != null:
		v.character_art.modulate.a = 0.0
		if v.tween_misc:
			v.tween_misc.kill()
		v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		v.tween_misc.tween_property(v.character_art, "modulate:a", 1.0, maxf(e.duration, 0.01))


func _on_summon_reserve_released(e: EventPackage) -> void:
	var d := _data(e)
	var summoned_id := int(d.get(Keys.SUMMONED_ID, 0))
	var card_uid := String(d.get(Keys.CARD_UID, ""))
	if summoned_id <= 0 or card_uid == "":
		return
	Events.summon_reserve_card_released.emit(summoned_id, card_uid)


func _on_scope_begin(_e: EventPackage) -> void:
	pass


func _on_scope_end(_e: EventPackage) -> void:
	pass


# ------------------------------------------------------------------------------
# Summon helpers
# ------------------------------------------------------------------------------

func _ensure_summon_view(e: EventPackage, animate: bool) -> CombatantView:
	var d := _data(e)
	var cid := int(d.get(Keys.SUMMONED_ID, 0))
	var g := _group_index(e)
	var idx := int(d.get(Keys.INSERT_INDEX, -1))
	if cid <= 0:
		return null

	var v := battle_view.get_or_create_combatant_view(cid, g, idx, animate)
	if v == null:
		return null

	v.apply_spawn_spec(d.get(Keys.SUMMON_SPEC, {}))
	return v


func _place_summon_for_windup(e: EventPackage, v: CombatantView) -> void:
	var d := _data(e)
	var g := _group_index(e)
	var insert_index := int(d.get(Keys.INSERT_INDEX, -1))
	var layout_count := int(d.get(Keys.WINDUP_LAYOUT_COUNT, 0))

	if layout_count <= 0:
		layout_count = _before_order(e).size()
	if layout_count <= 0:
		layout_count = battle_view.get_combatant_views_for_group(g).size()

	v.is_alive = false

	if v.tween_move:
		v.tween_move.kill()

	var slot_global := battle_view.get_summon_slot_position_for_layout_count(g, insert_index, layout_count)
	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	v.position = group.to_local(slot_global)
	v.anchor_position = v.position
	v.has_anchor_position = true

	if v.character_art != null:
		var c := v.character_art.modulate
		c.a = 0.0
		v.character_art.modulate = c

	if v.tween_misc:
		v.tween_misc.kill()
	v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if v.character_art != null:
		v.tween_misc.tween_property(v.character_art, "modulate:a", 1.0, maxf(e.duration, 0.01))


# ------------------------------------------------------------------------------
# Attack presentation playback
# ------------------------------------------------------------------------------

func _on_attack_prep_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	battle_view.apply_focus(
		_make_focus_order(
			info.attacker_id,
			_coerce_int_array(info.get_all_target_ids()),
			duration
		)
	)


func _on_strike_windup_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	var attacker := battle_view.get_combatant(info.attacker_id)
	if attacker == null:
		return

	var o := StrikeWindupOrder.new()
	o.duration = duration
	o.attacker_id = info.attacker_id
	o.target_ids = info.get_all_target_ids()
	o.attack_mode = info.attack_mode
	o.projectile_scene_path = info.projectile_scene_path
	o.strike_count = info.strike_count
	o.total_hit_count = info.total_hit_count
	o.attack_info = info

	attacker.play_strike_windup(o, battle_view)


func _on_strike_followthrough_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	var attacker := battle_view.get_combatant(info.attacker_id)
	if attacker != null:
		var o := StrikeFollowthroughOrder.new()
		o.duration = duration
		o.attacker_id = info.attacker_id
		o.target_ids = info.get_all_target_ids()
		o.attack_mode = info.attack_mode
		o.strike_count = info.strike_count
		o.total_hit_count = info.total_hit_count
		o.has_lethal_hit = info.has_lethal_hit
		o.attack_info = info
		attacker.play_strike_followthrough(o, battle_view)

	for tid in info.get_all_target_ids():
		var target := battle_view.get_combatant(int(tid))
		if target != null:
			target.play_attack_received_followthrough(info, duration)


func _on_attack_wrapup_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	var e := BattleEvent.new(BattleEvent.Type.STRIKE)
	e.data = {
		Keys.SOURCE_ID: info.attacker_id,
		Keys.ATTACK_MODE: info.attack_mode,
		Keys.STRIKE_COUNT: info.strike_count,
	}
	_on_attack_wrapup(_make_epkg_from_event(e, duration))


# ------------------------------------------------------------------------------
# Timeline presentation playback
# ------------------------------------------------------------------------------

func _on_action_focus_from_timeline(info: ActionTimelinePresentationInfo, duration: float) -> void:
	if info == null:
		return

	battle_view.apply_focus(
		_make_focus_order(
			info.actor_id,
			_coerce_int_array(info.get_all_target_ids()),
			duration
		)
	)


func _on_action_windup_from_timeline(info: ActionTimelinePresentationInfo, duration: float) -> void:
	if info == null:
		return

	for step in info.steps:
		if step == null or step.marker == null:
			continue

		if int(step.marker.type) == int(BattleEvent.Type.SUMMONED):
			var epkg := _make_epkg_from_event(step.marker, duration)
			var v := _ensure_summon_view(epkg, true)
			if v != null:
				_place_summon_for_windup(epkg, v)


func _on_action_followthrough_from_timeline(info: ActionTimelinePresentationInfo, duration: float) -> void:
	if info == null:
		return

	for step in info.steps:
		if step == null or step.marker == null:
			continue

		if int(step.marker.type) == int(BattleEvent.Type.SUMMONED):
			_on_summon_followthrough(_make_epkg_from_event(step.marker, duration))
