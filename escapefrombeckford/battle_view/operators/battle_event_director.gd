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

func on_director_cue(cue: DirectorCue, gen: int) -> void:
	if cue == null or battle_view == null:
		return
	if !battle_view._playing or gen != battle_view._playback_gen:
		return

	for order in cue.orders:
		_start_order(order)

	for be in cue.events:
		if be == null:
			continue

		match int(be.type):
			BattleEvent.Type.SUMMONED, \
			BattleEvent.Type.DIED, \
			BattleEvent.Type.FADED, \
			BattleEvent.Type.MOVED:
				continue

		var ep := _make_epkg_from_event(be, 0.0)
		ep.is_planned = true
		on_event(ep)

func _start_order(order: PresentationOrder) -> void:
	if order == null or battle_view == null:
		return
	#print(_debug_start_order_line(order))
	match int(order.kind):
		PresentationOrder.Kind.FOCUS:
			_start_focus_order(order as FocusPresentationOrder)

		PresentationOrder.Kind.CLEAR_FOCUS:
			_start_clear_focus_order(order as ClearFocusPresentationOrder)

		PresentationOrder.Kind.MELEE_WINDUP:
			_start_melee_windup_order(order as MeleeWindupPresentationOrder)

		PresentationOrder.Kind.MELEE_STRIKE:
			_start_melee_strike_order(order as MeleeStrikePresentationOrder)

		PresentationOrder.Kind.RANGED_WINDUP:
			_start_ranged_windup_order(order as RangedWindupPresentationOrder)

		PresentationOrder.Kind.RANGED_FIRE:
			_start_ranged_fire_order(order as RangedFirePresentationOrder)

		PresentationOrder.Kind.IMPACT:
			_start_impact_order(order as ImpactPresentationOrder)

		PresentationOrder.Kind.SUMMON_WINDUP:
			_start_summon_windup_order(order as SummonWindupPresentationOrder)

		PresentationOrder.Kind.SUMMON_POP:
			_start_summon_pop_order(order as SummonPopPresentationOrder)

		PresentationOrder.Kind.STATUS_WINDUP:
			_start_status_windup_order(order as StatusWindupPresentationOrder)

		PresentationOrder.Kind.STATUS_POP:
			_start_status_pop_order(order as StatusPopPresentationOrder)

		PresentationOrder.Kind.DEATH:
			_start_death_order(order as DeathPresentationOrder)

		PresentationOrder.Kind.FADE:
			_start_fade_order(order as FadePresentationOrder)
			
		PresentationOrder.Kind.GROUP_LAYOUT:
			_start_group_layout_order(order as GroupLayoutPresentationOrder)

func _start_focus_order(order: FocusPresentationOrder) -> void:
	if order == null:
		return

	var o := FocusOrder.new()
	o.duration = order.visual_sec if order.visual_sec > 0.0 else 0.35
	o.attacker_id = int(order.actor_id)
	o.target_ids = order.target_ids
	o.dim_bg = order.dim_bg
	o.dim_uninvolved = order.dim_uninvolved
	o.scale_involved = order.scale_involved
	o.scale_uninvolved = order.scale_uninvolved
	o.drift_involved = order.drift_involved

	battle_view.apply_focus(o)

func _start_clear_focus_order(order: ClearFocusPresentationOrder) -> void:
	if order == null:
		return
	var dur := order.visual_sec if order.visual_sec > 0.0 else 0.30
	battle_view.clear_focus(dur)

func _start_melee_windup_order(order: MeleeWindupPresentationOrder) -> void:
	if order == null:
		return
	var attacker := battle_view.get_combatant(int(order.actor_id))
	if attacker != null:
		attacker.play_presentation_order(order, battle_view)

func _start_melee_strike_order(order: MeleeStrikePresentationOrder) -> void:
	if order == null:
		return
	var attacker := battle_view.get_combatant(int(order.actor_id))
	if attacker != null:
		attacker.play_presentation_order(order, battle_view)

func _start_ranged_windup_order(order: RangedWindupPresentationOrder) -> void:
	if order == null:
		return
	var attacker := battle_view.get_combatant(int(order.actor_id))
	if attacker != null:
		attacker.play_presentation_order(order, battle_view)

func _start_ranged_fire_order(order: RangedFirePresentationOrder) -> void:
	if order == null:
		return
	var attacker := battle_view.get_combatant(int(order.actor_id))
	if attacker != null:
		attacker.play_presentation_order(order, battle_view)

func _start_impact_order(order: ImpactPresentationOrder) -> void:
	if order == null:
		return
	var target := battle_view.get_combatant(int(order.target_id))
	if target != null:
		target.play_presentation_order(order, battle_view)


func _start_status_windup_order(order: StatusWindupPresentationOrder) -> void:
	if order == null:
		return

	# Minimal cosmetic: briefly mark targets as targeted.
	for tid in order.target_ids:
		var tv := battle_view.get_combatant(int(tid))
		if tv != null:
			tv.show_targeted(true)

func _start_status_pop_order(order: StatusPopPresentationOrder) -> void:
	if order == null:
		return

	# Placeholder cosmetic only. Raw STATUS event handles actual icon/state changes.
	var tv := battle_view.get_combatant(int(order.target_id))
	if tv != null:
		tv.play_hit()

func _start_summon_windup_order(order: SummonWindupPresentationOrder) -> void:
	if order == null:
		return

	var caster := battle_view.get_combatant(int(order.actor_id))
	if caster != null:
		caster.play_summon_windup(order.visual_sec if order.visual_sec > 0.0 else 0.18)

func _start_summon_pop_order(order: SummonPopPresentationOrder) -> void:
	if order == null:
		return

	var cid := int(order.summoned_id)
	var g := int(order.group_index)
	var idx := int(order.insert_index)

	var v := battle_view.get_or_create_combatant_view(cid, g, idx, true)
	if v == null:
		return

	if order.summon_spec != null and !order.summon_spec.is_empty():
		v.apply_spawn_spec(order.summon_spec)

	v.is_alive = true

	if v.character_art != null:
		var c := v.character_art.modulate
		c.a = 0.0
		v.character_art.modulate = c

		if v.tween_misc:
			v.tween_misc.kill()
		v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		v.tween_misc.tween_property(
			v.character_art,
			"modulate:a",
			1.0,
			maxf(order.visual_sec if order.visual_sec > 0.0 else 0.20, 0.01)
		)

func _start_death_order(order: DeathPresentationOrder) -> void:
	if order == null:
		return

	var be := BattleEvent.new(BattleEvent.Type.DIED)
	be.group_index = int(order.group_index)
	be.data = {
		Keys.TARGET_ID: int(order.target_id),
		Keys.GROUP_INDEX: int(order.group_index),
		Keys.AFTER_ORDER_IDS: order.after_order_ids,
	}

	var ep := _make_epkg_from_event(be, order.visual_sec if order.visual_sec > 0.0 else 0.24)
	_on_death_followthrough(ep)

func _start_fade_order(order: FadePresentationOrder) -> void:
	if order == null:
		return

	var be := BattleEvent.new(BattleEvent.Type.FADED)
	be.group_index = int(order.group_index)
	be.data = {
		Keys.TARGET_ID: int(order.target_id),
		Keys.GROUP_INDEX: int(order.group_index),
		Keys.AFTER_ORDER_IDS: order.after_order_ids,
	}

	var ep := _make_epkg_from_event(be, order.visual_sec if order.visual_sec > 0.0 else 0.20)
	_on_fade_followthrough(ep)


func _start_group_layout_order(order: GroupLayoutPresentationOrder) -> void:
	if order == null or battle_view == null:
		return

	var ctx := GroupLayoutOrder.new()
	ctx.group_index = int(order.group_index)
	ctx.order = order.order_ids
	ctx.animate_to_position = bool(order.animate)
	battle_view.set_group_order(ctx)


func on_event(e: EventPackage) -> void:
	if e == null or e.event == null or battle_view == null:
		return

	if e.is_planned:
		match int(e.event.type):
			BattleEvent.Type.SUMMONED, \
			BattleEvent.Type.DIED, \
			BattleEvent.Type.FADED, \
			BattleEvent.Type.MOVED:
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
		BattleEvent.Type.MANA:
			_on_mana(e)
		BattleEvent.Type.VICTORY:
			_on_victory(e)
		BattleEvent.Type.DEFEAT:
			_on_defeat(e)
		BattleEvent.Type.HEAL_APPLIED:
			_on_heal_applied(e)
		BattleEvent.Type.CHANGE_MAX_HEALTH:
			_on_change_max_health(e)
		_:
			pass


# ------------------------------------------------------------------------------
# Director phase playback
# ------------------------------------------------------------------------------

func _play_focus_action(a: DirectorAction) -> void:
	if a == null:
		return

	# Focus can use either AttackPresentationInfo or a StrikeFollowthroughSlice (useful if you ever do refocus)
	var slice := _as_strike_slice(a)
	if slice != null and slice.attack != null:
		_on_attack_prep_from_info(slice.attack, a.duration_sec)
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

	var slice := _as_strike_slice(a)
	if slice != null:
		_on_strike_windup_from_slice(slice, a.duration_sec)
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

	var slice := _as_strike_slice(a)
	if slice != null:
		_on_strike_followthrough_from_slice(slice, a.duration_sec)

		# Only non-structural raw events here
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

	_apply_payload_events(
		a.payload,
		a.duration_sec,
		{
			BattleEvent.Type.STATUS: true,
			BattleEvent.Type.SET_INTENT: true,
			BattleEvent.Type.TURN_STATUS: true,
		}
	)


# ------------------------------------------------------------------------------
# Shared event/data helpers
# ------------------------------------------------------------------------------

func _as_strike_slice(a: DirectorAction) -> StrikeFollowthroughSlice:
	if a == null:
		return null
	return a.presentation as StrikeFollowthroughSlice

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
		var ep := _make_epkg_from_event(be, duration)
		ep.is_planned = true
		on_event(ep)


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

func _make_mana_view_order(e: EventPackage) -> ManaViewOrder:
	var d := _data(e)
	var o := ManaViewOrder.new()
	o.duration = e.duration
	o.source_id = int(d.get(Keys.SOURCE_ID, 0))
	o.before_mana = int(d.get(Keys.BEFORE_MANA, 0))
	o.after_mana = int(d.get(Keys.AFTER_MANA, 0))
	o.before_max_mana = int(d.get(Keys.BEFORE_MAX_MANA, 0))
	o.after_max_mana = int(d.get(Keys.AFTER_MAX_MANA, 0))
	o.reason = String(d.get(Keys.REASON, ""))
	return o

#func _relayout_groups_after_resolve() -> void:
	#if battle_view == null:
		#return
#
	#if battle_view.friendly_group != null:
		#battle_view.friendly_group.relayout_alive_immediate(true)
#
	#if battle_view.enemy_group != null:
		#battle_view.enemy_group.relayout_alive_immediate(true)

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

	if target_combatant == null:
		return

	target_combatant.set_health(after_health, lethal)

	if e.is_planned:
		return

	target_combatant.play_hit()
	target_combatant.pop_damage_number(amount)

func _on_heal_applied(e: EventPackage) -> void:
	var d := _data(e)
	var tid := int(d.get(Keys.TARGET_ID, 0))
	var healed := int(d.get(Keys.HEALED_AMOUNT, 0))
	var after_health := int(d.get(Keys.AFTER_HEALTH, 0))

	var target := battle_view.get_combatant(tid)
	if target == null:
		return

	target.set_health(after_health, false)

	if e.is_planned:
		return

	if target.has_method("play_heal_fx"):
		target.play_heal_fx()

	if target.has_method("pop_heal_number"):
		target.pop_heal_number(healed)

func _on_change_max_health(e: EventPackage) -> void:
	print("director _on_change_max_health")
	var d := _data(e)
	var tid := int(d.get(Keys.TARGET_ID, 0))
	if tid <= 0:
		return

	var v := battle_view.get_combatant(tid)
	if v == null:
		return

	var after_health := int(d.get(Keys.AFTER_HEALTH, v.health))
	var after_max_health := int(d.get(Keys.AFTER_MAX_HEALTH, v.max_health))
	var before_health := int(d.get(Keys.BEFORE_HEALTH, v.health))
	var before_max_health := int(d.get(Keys.BEFORE_MAX_HEALTH, v.max_health))
	print("director before max: %s, after max: %s" % [before_max_health, after_max_health])
	v.max_health = after_max_health
	v.health = clampi(after_health, 0, after_max_health)

	if v.health_bar != null:
		v.health_bar.update_health_view(v.max_health, v.health)

	# Optional tiny cosmetic when max health changes.
	# Only pop a number if health actually changed.
	var delta_health := after_health - before_health
	if !e.is_planned and delta_health > 0:
		v.pop_damage_number(delta_health) # replace later with heal/max-hp popup if desired

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
	#print("battle_event_director.gd _on_death_followthrough()")
	var dead_id := _target_id(e)
	var g := _group_index(e)
	var dur := maxf(e.duration, 0.01)

	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)

	var dead_view := battle_view.get_combatant(dead_id)
	if dead_view == null:
		return

	dead_view.play_death_reaction(dur)
	dead_view.is_alive = false

	await battle_view.get_tree().create_timer(dur).timeout

	if is_instance_valid(dead_view):
		dead_view.queue_free()

	battle_view.combatants_by_cid.erase(dead_id)


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

func _on_victory(e: EventPackage) -> void:
	var d := _data(e)
	#var reason := String(d.get(Keys.REASON, ""))
	# Optional: stop playback visuals immediately if you want.
	# if battle_view != null: battle_view.stop_playback()
	Events.request_victory.emit()

func _on_defeat(e: EventPackage) -> void:
	var d := _data(e)
	#var reason := String(d.get(Keys.REASON, ""))
	# Optional: stop playback visuals immediately if you want.
	# if battle_view != null: battle_view.stop_playback()
	Events.request_defeat.emit()

func _on_scope_begin(_e: EventPackage) -> void:
	pass


func _on_scope_end(_e: EventPackage) -> void:
	pass

func _on_mana(e: EventPackage) -> void:
	var d := _data(e)
	var o := _make_mana_view_order(e)

	# View->UI bridge: Battle.gd owns the UI node, so we broadcast.
	Events.mana_view_update.emit(o)



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

	# Keep entirely hidden until SUMMON_POP
	if v.character_art != null:
		var c := v.character_art.modulate
		c.a = 0.0
		v.character_art.modulate = c


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
	o.target_ids = _coerce_int_array(info.get_all_target_ids())
	o.attack_mode = info.attack_mode
	o.projectile_scene_path = info.projectile_scene_path

	# For melee windup, you might want "whole attack" context (strike_count > 1)
	o.strike_count = maxi(1, info.strike_count)
	o.total_hit_count = maxi(1, info.total_hit_count)
	o.attack_info = info

	attacker.play_strike_windup(o, battle_view)


func _on_strike_followthrough_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	# Treat as "one strike" fallback:
	# - melee: attacker pose
	# - ranged: do nothing (impacts should be driven via slice)
	var attacker := battle_view.get_combatant(info.attacker_id)
	if attacker != null:
		var o := StrikeFollowthroughOrder.new()
		o.duration = duration
		o.attacker_id = info.attacker_id
		o.target_ids = _coerce_int_array(info.get_all_target_ids())
		o.attack_mode = info.attack_mode
		o.strike_count = 1
		o.strike_index = 0
		o.total_hit_count = maxi(1, info.total_hit_count)
		o.has_lethal_hit = bool(info.has_lethal_hit)
		o.attack_info = info
		attacker.play_strike_followthrough(o, battle_view)

	# Targets are NOT driven here anymore; slice should handle per-strike hits.

func _on_strike_windup_from_slice(slice: StrikeFollowthroughSlice, duration: float) -> void:
	if slice == null or slice.attack == null:
		return

	var atk := slice.attack
	var attacker := battle_view.get_combatant(atk.attacker_id)
	if attacker == null:
		return

	var o := StrikeWindupOrder.new()
	o.duration = duration
	o.attacker_id = atk.attacker_id
	o.attack_mode = atk.attack_mode
	o.projectile_scene_path = atk.projectile_scene_path
	o.attack_info = atk

	# key: this WINDUP is for ONE strike (one projectile)
	o.strike_count = 1
	o.strike_index = int(slice.strike_index)

	# target selection for THIS strike
	o.target_ids = _coerce_int_array(slice.get_target_ids())

	attacker.play_strike_windup(o, battle_view)

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

func _on_strike_followthrough_from_slice(slice: StrikeFollowthroughSlice, duration: float) -> void:
	if slice == null or slice.attack == null:
		return

	var atk := slice.attack
	var si := int(slice.strike_index)

	# 1) Attacker followthrough pose (melee only; ranged does nothing here)
	var attacker := battle_view.get_combatant(atk.attacker_id)
	if attacker != null:
		var o := StrikeFollowthroughOrder.new()
		o.duration = duration
		o.attacker_id = atk.attacker_id
		o.target_ids = _coerce_int_array(slice.get_target_ids())
		o.attack_mode = atk.attack_mode

		# This beat is ONE strike
		o.strike_count = 1
		o.strike_index = si
		o.total_hit_count = slice.strike.hit_count if slice.strike != null else 1
		o.has_lethal_hit = slice.strike.has_lethal_hit if slice.strike != null else false
		o.attack_info = atk

		attacker.play_strike_followthrough(o, battle_view)


	# 3) Targets: apply ONLY this strike's hits
	if slice.strike != null:
		for h in slice.strike.hits:
			if h == null:
				continue
			var target := battle_view.get_combatant(int(h.target_id))
			if target != null:
				target.play_received_hit_from_hitinfo(h, duration)

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

func _debug_start_order_line(order: PresentationOrder) -> String:
	if order == null:
		return "[ORDER] <null>"

	var kind_name := str(int(order.kind))
	if int(order.kind) >= 0 and int(order.kind) < PresentationOrder.Kind.keys().size():
		kind_name = PresentationOrder.Kind.keys()[int(order.kind)]

	return "[ORDER] kind=%s %s" % [
		kind_name,
		_debug_order_payload(order),
	]


func _debug_order_payload(order: PresentationOrder) -> String:
	if order == null:
		return ""

	var bits: Array[String] = []
	bits.append("a=%d" % int(order.actor_id))

	if order.target_ids != null and !order.target_ids.is_empty():
		bits.append("tgts=%s" % str(order.target_ids))

	if order.visual_sec > 0.0:
		bits.append("vis=%.2f" % float(order.visual_sec))

	match int(order.kind):
		PresentationOrder.Kind.MELEE_WINDUP:
			var o := order as MeleeWindupPresentationOrder
			if o != null:
				bits.append("strikes=%d" % int(o.strike_count))
				bits.append("hits=%d" % int(o.total_hit_count))

		PresentationOrder.Kind.MELEE_STRIKE:
			var o2 := order as MeleeStrikePresentationOrder
			if o2 != null:
				bits.append("i=%d" % int(o2.strike_index))
				bits.append("n=%d" % int(o2.strikes_total))
				bits.append("hits=%d" % int(o2.total_hit_count))
				bits.append("lethal=%s" % str(bool(o2.has_lethal)))

		PresentationOrder.Kind.RANGED_WINDUP:
			var o3 := order as RangedWindupPresentationOrder
			if o3 != null:
				bits.append("i=%d" % int(o3.strike_index))
				bits.append("strikes=%d" % int(o3.strike_count))
				bits.append("hits=%d" % int(o3.total_hit_count))

		PresentationOrder.Kind.RANGED_FIRE:
			var o4 := order as RangedFirePresentationOrder
			if o4 != null:
				bits.append("i=%d" % int(o4.strike_index))
				bits.append("n=%d" % int(o4.strikes_total))
				bits.append("hits=%d" % int(o4.total_hit_count))
				bits.append("lethal=%s" % str(bool(o4.has_lethal)))
				if o4.projectile_scene_path != "":
					bits.append("proj=%s" % o4.projectile_scene_path.get_file())

		PresentationOrder.Kind.IMPACT:
			var o5 := order as ImpactPresentationOrder
			if o5 != null:
				bits.append("t=%d" % int(o5.target_id))
				bits.append("i=%d" % int(o5.strike_index))
				bits.append("amt=%d" % int(o5.amount))
				bits.append("hp=%d" % int(o5.after_health))
				bits.append("lethal=%s" % str(bool(o5.was_lethal)))

		PresentationOrder.Kind.SUMMON_WINDUP:
			var o6 := order as SummonWindupPresentationOrder
			if o6 != null:
				bits.append("summoned=%d" % int(o6.summoned_id))
				bits.append("g=%d" % int(o6.group_index))
				bits.append("idx=%d" % int(o6.insert_index))
				bits.append("before=%s" % str(o6.before_order_ids))

		PresentationOrder.Kind.SUMMON_POP:
			var o7 := order as SummonPopPresentationOrder
			if o7 != null:
				bits.append("summoned=%d" % int(o7.summoned_id))
				bits.append("g=%d" % int(o7.group_index))
				bits.append("idx=%d" % int(o7.insert_index))
				bits.append("after=%s" % str(o7.after_order_ids))

		PresentationOrder.Kind.STATUS_POP:
			var o8 := order as StatusPopPresentationOrder
			if o8 != null:
				bits.append("src=%d" % int(o8.source_id))
				bits.append("t=%d" % int(o8.target_id))
				bits.append("status=%s" % String(o8.status_id))
				bits.append("op=%d" % int(o8.op))
				bits.append("int=%d" % int(o8.intensity))
				bits.append("dur=%d" % int(o8.turns_duration))

		PresentationOrder.Kind.DEATH:
			var o9 := order as DeathPresentationOrder
			if o9 != null:
				bits.append("t=%d" % int(o9.target_id))
				bits.append("g=%d" % int(o9.group_index))
				bits.append("after=%s" % str(o9.after_order_ids))

		PresentationOrder.Kind.FADE:
			var o10 := order as FadePresentationOrder
			if o10 != null:
				bits.append("t=%d" % int(o10.target_id))
				bits.append("g=%d" % int(o10.group_index))
				bits.append("after=%s" % str(o10.after_order_ids))
		PresentationOrder.Kind.GROUP_LAYOUT:
			var og := order as GroupLayoutPresentationOrder
			if og != null:
				bits.append("g=%d" % int(og.group_index))
				bits.append("order=%s" % str(og.order_ids))
				bits.append("anim=%s" % str(bool(og.animate)))

	return " ".join(bits)
