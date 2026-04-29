# battle_event_director.gd

class_name BattleEventDirector extends RefCounted

var battle_view: BattleView
var click: Sound
var _summon_sound_cache := {}
var _vfx_payload_sound_cache := {}

@export var spawn_pause_sec: float = 0.04
@export var summon_pause_sec: float = 0.06
@export var hit_pause_sec: float = 0.05


# ------------------------------------------------------------------------------
# Entry points
# ------------------------------------------------------------------------------

func bind(new_battle_view: BattleView) -> void:
	battle_view = new_battle_view
	click = battle_view.click_sound
	_summon_sound_cache.clear()
	_vfx_payload_sound_cache.clear()


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

	# Raw playback path: events are applied immediately in chunk order with no
	# intermediate timeline/cue model.
	for be in pkg.beat:
		if be == null:
			continue
		on_event(_make_epkg_from_event(be, pkg.duration_sec))

func on_director_cue(cue: DirectorCue, gen: int) -> void:
	if cue == null or battle_view == null:
		return
	if !battle_view._playing or gen != battle_view._playback_gen:
		return

	var has_move_diag := false
	for order in cue.orders:
		if order != null and int(order.kind) == int(PresentationOrder.Kind.GROUP_LAYOUT):
			has_move_diag = true
			break
	if !has_move_diag:
		for be in cue.events:
			if be != null and int(be.type) == int(BattleEvent.Type.MOVED):
				has_move_diag = true
				break


	# Planned playback path: start all presentation orders for the beat, then
	# apply the beat's state-change events. By this point the original raw events
	# have already been grouped and time-quantized by the compiler.
	for order in cue.orders:
		_start_order(order)

	for be in cue.events:
		if be == null:
			continue

		if _is_presentation_only_planned_event_type(int(be.type)):
			continue

		var ep := _make_epkg_from_event(be, 0.0)
		ep.is_planned = true
		on_event(ep)


func _cue_has_debug_reaction_tags(cue: DirectorCue) -> bool:
	if cue == null:
		return false

	for tag in cue.tags:
		match StringName(tag):
			&"reaction", &"strike", &"fire", &"impact", &"focus", &"clear_focus":
				return true

	return false

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

		PresentationOrder.Kind.RANGED_CLEAVE:
			_start_ranged_cleave_order(order as RangedFirePresentationOrder)

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

		PresentationOrder.Kind.REMOVAL:
			_start_removal_order(order)
			
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
	#print("VIEW ranged fire projectile uid/path: ", order.projectile_scene_path)
	var attacker := battle_view.get_combatant(int(order.actor_id))
	if attacker != null:
		attacker.play_presentation_order(order, battle_view)

func _start_ranged_cleave_order(order: RangedFirePresentationOrder) -> void:
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

	var caster := battle_view.get_combatant(int(order.actor_id))
	if caster != null:
		caster.play_presentation_order(order, battle_view)

	for tid in order.target_ids:
		var tv := battle_view.get_combatant(int(tid))
		if tv != null and tv != caster:
			tv.play_presentation_order(order, battle_view)

func _start_status_pop_order(order: StatusPopPresentationOrder) -> void:
	if order == null:
		return

	var source := battle_view.get_combatant(int(order.source_id))
	if source != null:
		source.play_presentation_order(order, battle_view)

	var tv := battle_view.get_combatant(int(order.target_id))
	if tv != null and tv != source:
		tv.play_presentation_order(order, battle_view)

func _start_summon_windup_order(order: SummonWindupPresentationOrder) -> void:
	if order == null:
		return

	var caster := battle_view.get_combatant(int(order.actor_id))
	if caster != null:
		caster.play_summon_windup(order.visual_sec if order.visual_sec > 0.0 else 0.18)

func _start_summon_pop_order(order: SummonPopPresentationOrder) -> void:
	if order == null:
		return

	var caster := battle_view.get_combatant(int(order.actor_id))
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
		c.a = 1.0
		v.character_art.modulate = c

	var summon_sound := _resolve_summon_sound(String(order.summon_sound_uid))
	if summon_sound != null:
		SFXPlayer.play(summon_sound)

	_apply_group_order(g, _coerce_int_array(order.after_order_ids), true)

	_play_default_summon_pop_fx(v)

	if caster != null:
		caster.clear_strike_pose(order.visual_sec if order.visual_sec > 0.0 else 0.20)


func _resolve_summon_sound(summon_sound_ref: String) -> Sound:
	if summon_sound_ref.is_empty():
		return null
	if _summon_sound_cache.has(summon_sound_ref):
		return _summon_sound_cache[summon_sound_ref] as Sound

	var sound := load(summon_sound_ref) as Sound
	if sound == null:
		push_warning("BattleEventDirector._resolve_summon_sound(): failed to load summon sound %s" % summon_sound_ref)
		return null

	_summon_sound_cache[summon_sound_ref] = sound
	return sound

func _start_removal_order(order) -> void:
	if order == null:
		return

	var be := BattleEvent.new(BattleEvent.Type.REMOVED)
	be.group_index = int(order.group_index)
	be.data = {
		Keys.TARGET_ID: int(order.target_id),
		Keys.GROUP_INDEX: int(order.group_index),
		Keys.AFTER_ORDER_IDS: order.after_order_ids,
		Keys.REMOVAL_TYPE: int(order.removal_type),
	}

	var default_sec := 0.20 if int(order.removal_type) == int(Removal.Type.FADE) else 0.24
	var ep := _make_epkg_from_event(be, order.visual_sec if order.visual_sec > 0.0 else default_sec)
	_on_removal_followthrough(ep)


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

	if e.is_planned and _is_presentation_only_planned_event_type(int(e.event.type)):
		return

	_emit_encounter_observed_event(e)

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
		BattleEvent.Type.REMOVED:
			_on_removed(e)
		BattleEvent.Type.SET_INTENT:
			_on_set_intent(e)
		BattleEvent.Type.SCOPE_BEGIN:
			_on_scope_begin(e)
		BattleEvent.Type.SCOPE_END:
			_on_scope_end(e)
		BattleEvent.Type.TURN_STATUS:
			_on_turn_status(e)
		BattleEvent.Type.ARCANUM_PROC:
			_on_arcanum_proc(e)
		BattleEvent.Type.ARCANUM_STATE_CHANGED:
			_on_arcanum_state_changed(e)
		BattleEvent.Type.PLAYER_INPUT_REACHED:
			var actor_id := int(e.event.data.get(Keys.ACTOR_ID, 0)) if e.event.data != null else 0
			#print("[TRACE battle_event_director] PLAYER_INPUT_REACHED actor_id=%d seq=%d" % [actor_id, int(e.event.seq)])
			Events.player_input_view_reached.emit(actor_id)
		BattleEvent.Type.CARD_PLAYED:
			pass
		BattleEvent.Type.END_TURN_PRESSED:
			pass
		BattleEvent.Type.DISCARD_CARDS:
			_on_discard_cards(e)
		BattleEvent.Type.DISCARD_REQUESTED:
			_on_discard_requested(e)
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
		BattleEvent.Type.MODIFY_BATTLE_CARD:
			_on_modify_battle_card(e)
		BattleEvent.Type.DRAW_CARDS:
			_on_draw_cards(e)
		_:
			if !_is_silent_noop_event_type(int(e.event.type)):
				push_warning("BattleEventDirector: unhandled event type in playback: %s planned=%s" % [_event_type_name(int(e.event.type)), str(bool(e.is_planned))])

func _emit_encounter_observed_event(e: EventPackage) -> void:
	var event_name := _encounter_event_name(int(e.event.type))
	if event_name == &"":
		return
	var d := _data(e)
	var observed := EncounterObservedEvent.new()
	observed.name = event_name
	observed.battle_event_type = int(e.event.type)
	observed.seq = int(e.event.seq)
	observed.actor_id = int(d.get(Keys.ACTOR_ID, 0))
	observed.move_unit_id = int(d.get(Keys.MOVE_UNIT_ID, 0))
	observed.source_id = int(d.get(Keys.SOURCE_ID, 0))
	observed.target_id = int(d.get(Keys.TARGET_ID, 0))
	observed.group_index = int(d.get(Keys.GROUP_INDEX, e.event.group_index))
	observed.active_id = int(d.get(Keys.ACTIVE_ID, 0))
	observed.card_id = StringName(String(d.get(Keys.CARD_ID, "")))
	observed.card_uid = StringName(String(d.get(Keys.CARD_UID, "")))
	observed.card_proto_path = String(d.get(Keys.PROTO, ""))
	observed.insert_index = int(d.get(Keys.INSERT_INDEX, -1))
	observed.target_ids = _to_packed_int_array(d.get(Keys.TARGETS, d.get(Keys.TARGET_IDS, PackedInt32Array())))
	observed.summoned_ids = _to_packed_int_array(d.get(Keys.SUMMONED_IDS, PackedInt32Array()))
	if observed.summoned_ids.is_empty() and int(d.get(Keys.SUMMONED_ID, 0)) > 0:
		observed.summoned_ids = PackedInt32Array([int(d.get(Keys.SUMMONED_ID, 0))])
	observed.data = d.duplicate(true)
	Events.encounter_observed_event.emit(observed)

func _encounter_event_name(event_type: int) -> StringName:
	match event_type:
		BattleEvent.Type.CARD_PLAYED:
			return &"card_played"
		BattleEvent.Type.SUMMONED:
			return &"summoned"
		BattleEvent.Type.MOVED:
			return &"moved"
		BattleEvent.Type.TURN_STATUS:
			return &"turn_status"
		BattleEvent.Type.PLAYER_INPUT_REACHED:
			return &"player_input_reached"
		BattleEvent.Type.END_TURN_PRESSED:
			return &"end_turn_pressed"
		BattleEvent.Type.DRAW_CARDS:
			return &"draw_cards"
		BattleEvent.Type.VICTORY:
			return &"victory"
		BattleEvent.Type.DEFEAT:
			return &"defeat"
		BattleEvent.Type.DISCARD_REQUESTED:
			return &"discard_requested"
	return &""

func _to_packed_int_array(value: Variant) -> PackedInt32Array:
	if value is PackedInt32Array:
		return value.duplicate()
	var packed := PackedInt32Array()
	if value is Array:
		for entry in value:
			packed.append(int(entry))
	return packed


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


func _removal_type(e: EventPackage) -> int:
	return int(_data(e).get(Keys.REMOVAL_TYPE, int(Removal.Type.DEATH)))


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
		if _is_presentation_only_planned_event_type(int(be.type)):
			continue
		var ep := _make_epkg_from_event(be, duration)
		ep.is_planned = true
		on_event(ep)


func _is_presentation_only_planned_event_type(event_type: int) -> bool:
	match event_type:
		BattleEvent.Type.SUMMONED, \
		BattleEvent.Type.REMOVED, \
		BattleEvent.Type.MOVED:
			return true
	return false


func _is_silent_noop_event_type(event_type: int) -> bool:
	match event_type:
		BattleEvent.Type.TURN_GROUP_BEGIN, \
		BattleEvent.Type.TURN_GROUP_END, \
		BattleEvent.Type.ACTOR_BEGIN, \
		BattleEvent.Type.ACTOR_END, \
		BattleEvent.Type.STRIKE, \
		BattleEvent.Type.CLEAVE, \
		BattleEvent.Type.CARD_PLAYED, \
		BattleEvent.Type.CARD_MUTATED, \
		BattleEvent.Type.DEBUG, \
		BattleEvent.Type.ARCANA_PROC, \
		BattleEvent.Type.DISCARD_RESOLVED:
			return true
	return false


func _event_type_name(event_type: int) -> String:
	if event_type >= 0 and event_type < BattleEvent.Type.keys().size():
		return BattleEvent.Type.keys()[event_type]
	return str(event_type)


func _make_status_applied_order(e: EventPackage) -> StatusAppliedOrder:
	var d := _data(e)

	var o := StatusAppliedOrder.new()
	o.duration = e.duration
	o.source_id = int(d.get(Keys.SOURCE_ID, 0))
	o.target_id = int(d.get(Keys.TARGET_ID, 0))
	o.status_id = d.get(Keys.STATUS_ID, &"")
	o.pending = bool(d.get(Keys.AFTER_PENDING, d.get(Keys.STATUS_PENDING, false)))
	o.before_pending = bool(d.get(Keys.BEFORE_PENDING, o.pending))
	o.after_pending = bool(d.get(Keys.AFTER_PENDING, o.pending))
	o.before_token_id = int(d.get(Keys.BEFORE_TOKEN_ID, 0))
	o.after_token_id = int(d.get(Keys.AFTER_TOKEN_ID, 0))
	o.stacks = int(d.get(Keys.AFTER_STACKS, d.get(Keys.STACKS, 1)))
	o.data = d.get(Keys.STATUS_DATA, {}).duplicate(true) if d.get(Keys.STATUS_DATA, {}) is Dictionary else {}

	return o


func _make_status_removed_order(e: EventPackage) -> StatusRemovedOrder:
	var d := _data(e)

	var o := StatusRemovedOrder.new()
	o.duration = e.duration
	o.source_id = int(d.get(Keys.SOURCE_ID, 0))
	o.target_id = int(d.get(Keys.TARGET_ID, 0))
	o.status_id = d.get(Keys.STATUS_ID, &"")
	o.pending = bool(d.get(Keys.STATUS_PENDING, false))
	o.before_token_id = int(d.get(Keys.BEFORE_TOKEN_ID, 0))
	o.after_token_id = int(d.get(Keys.AFTER_TOKEN_ID, 0))
	o.stacks = int(d.get(Keys.BEFORE_STACKS, d.get(Keys.STACKS, 1)))
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

	var summon_spec: Dictionary = d.get(Keys.SUMMON_SPEC, {})
	v.apply_spawn_spec(summon_spec)
	_apply_group_order(g, _after_order(e), false)


func _on_turn_status(e: EventPackage) -> void:
	var d := _data(e)
	var active_id := int(d.get(Keys.ACTIVE_ID, 0))
	var pending_ids: PackedInt32Array = d.get(Keys.PENDING_IDS, PackedInt32Array())
	var group_index := int(d.get(Keys.GROUP_INDEX, e.event.group_index))
	var player_id := int(d.get(Keys.PLAYER_ID, 0))

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

	Events.turn_status_view_changed.emit(group_index, active_id, pending_ids, player_id)


func _on_arcanum_proc(e: EventPackage) -> void:
	if e == null:
		return
	var d := _data(e)
	var arcanum_id: StringName = d.get(Keys.ARCANUM_ID, &"")
	var proc := int(d.get(Keys.PROC, -1))
	var source_id := int(d.get(Keys.SOURCE_ID, 0))
	if arcanum_id == &"":
		return
	Events.arcanum_view_activated.emit(arcanum_id, proc, source_id)


func _on_arcanum_state_changed(e: EventPackage) -> void:
	if e == null:
		return
	var d := _data(e)
	var arcanum_id: StringName = d.get(Keys.ARCANUM_ID, &"")
	if arcanum_id == &"":
		return
	var stacks := int(d.get(Keys.AFTER_STACKS, -1))
	Events.arcanum_stacks_changed.emit(arcanum_id, stacks)


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
	o.projectile_scene_path = String(d.get(Keys.PROJECTILE_SCENE, "uid://bxmhi3urqmpfh"))
	o.strike_count = int(d.get(Keys.STRIKE_COUNT, 1))
	o.strike_index = int(d.get(Keys.STRIKE_INDEX, 0))
	o.chained_from_previous = bool(d.get(Keys.CHAINED_FROM_PREVIOUS, false))
	o.origin_strike_index = int(d.get(Keys.ORIGIN_STRIKE_INDEX, -1))
	o.chain_source_target_id = int(d.get(Keys.CHAIN_SOURCE_TARGET_ID, 0))

	if o.attack_mode == Attack.Mode.RANGED:
		print("VIEW ranged strike windup projectile uid/path: ", o.projectile_scene_path)

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
	o.strike_index = int(d.get(Keys.STRIKE_INDEX, 0))
	o.total_hit_count = int(d.get(Keys.TOTAL_HIT_COUNT, 1))
	o.has_lethal_hit = bool(d.get(Keys.HAS_LETHAL_HIT, false))
	o.chained_from_previous = bool(d.get(Keys.CHAINED_FROM_PREVIOUS, false))
	o.origin_strike_index = int(d.get(Keys.ORIGIN_STRIKE_INDEX, -1))
	o.chain_source_target_id = int(d.get(Keys.CHAIN_SOURCE_TARGET_ID, 0))

	attacker.play_strike_followthrough(o, battle_view)


func _on_moved(e: EventPackage) -> void:
	var d := _data(e)
	var group_index := int(d.get(Keys.GROUP_INDEX, int(e.event.group_index)))
	_apply_group_order(group_index, _after_order(e), true)


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
	_emit_player_battle_health_changed(tid, target_combatant.health, target_combatant.max_health)

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
	_emit_player_battle_health_changed(tid, target.health, target.max_health)

	if e.is_planned:
		return

	target.play_heal_fx()
	target.pop_heal_number(healed)

func _on_change_max_health(e: EventPackage) -> void:
	#print("director _on_change_max_health")
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
	#var before_max_health := int(d.get(Keys.BEFORE_MAX_HEALTH, v.max_health))
	#print("director before max: %s, after max: %s" % [before_max_health, after_max_health])
	v.max_health = after_max_health
	v.health = clampi(after_health, 0, after_max_health)

	if v.health_bar != null:
		v.health_bar.update_health_view(v.max_health, v.health)
	_emit_player_battle_health_changed(tid, v.health, v.max_health)

	# Optional tiny cosmetic when max health changes.
	# Only pop a number if health actually changed.
	var delta_health := after_health - before_health
	if !e.is_planned and delta_health > 0:
		v.pop_damage_number(delta_health) # replace later with heal/max-hp popup if desired


func _emit_player_battle_health_changed(target_id: int, current_health: int, max_health: int) -> void:
	var player_id := _get_player_id()
	if player_id <= 0 or int(target_id) != player_id:
		return
	Events.player_battle_health_changed.emit(int(current_health), int(max_health))


func _get_player_id() -> int:
	if battle_view == null or battle_view.sim_host == null:
		return 0
	var api := battle_view.sim_host.get_main_api()
	if api == null:
		return 0
	return int(api.get_player_id())


func _on_modify_battle_card(e: EventPackage) -> void:
	if e == null or e.event == null or e.is_planned:
		return

	var d := _data(e)
	var card_uid := String(d.get(Keys.CARD_UID, ""))
	if card_uid.is_empty():
		return

	var modified_fields = d.get(Keys.MODIFIED_FIELDS, {})
	if !(modified_fields is Dictionary):
		modified_fields = {}

	Events.modify_battle_card.emit(card_uid, modified_fields, String(d.get(Keys.REASON, "")))

func _on_status_changed(e: EventPackage) -> void:
	if e == null or e.event == null:
		return

	var d := _data(e)
	var target_id := int(d.get(Keys.TARGET_ID, 0))
	if !e.is_planned:
		Events.battle_status_changed.emit(target_id)
	var op := int(d.get(Keys.OP, 0))
	var target := battle_view.get_combatant(target_id)
	if target != null and target.status_view_grid != null and bool(d.get(Keys.STATUS_DISPLAY_VISIBLE, true)):
		if op == int(Status.OP.REMOVE):
			target.status_view_grid.remove_status(_make_status_removed_order(e))
		else:
			target.status_view_grid.apply_status(_make_status_applied_order(e))

	_refresh_status_depiction(e)


func _refresh_status_depiction(e: EventPackage) -> void:
	if e == null or e.event == null or battle_view == null:
		return
	if battle_view.status_catalog == null:
		return

	var d := _data(e)
	_refresh_status_depiction_for_data(d)

	if !bool(d.get(Keys.IS_PROJECTED, false)):
		return
	var status_data = d.get(Keys.STATUS_DATA, {})
	if !(status_data is Dictionary):
		return
	var projection_source_status_id: StringName = status_data.get(Keys.PROJECTION_SOURCE_STATUS_ID, &"")
	var status_id: StringName = d.get(Keys.STATUS_ID, &"")
	if projection_source_status_id == &"" or projection_source_status_id == status_id:
		return

	var source_depiction_data := d.duplicate(true)
	source_depiction_data[Keys.STATUS_ID] = projection_source_status_id
	_refresh_status_depiction_for_data(source_depiction_data)


func _refresh_status_depiction_for_data(d: Dictionary) -> void:
	var status_id: StringName = d.get(Keys.STATUS_ID, &"")
	if status_id == &"":
		return

	var proto := battle_view.status_catalog.get_proto(status_id)
	if proto == null or proto.status_depiction == null:
		return

	var depiction := proto.status_depiction
	var depiction_prefix := depiction.get_key_prefix(d)
	var depiction_key := depiction.get_key(d)
	if depiction_key.is_empty():
		return

	var is_remove := int(d.get(Keys.OP, 0)) == int(Status.OP.REMOVE)
	if is_remove:
		_clear_status_depiction_key_from_views(depiction_key)
	else:
		_clear_status_depiction_prefix_from_views(depiction_prefix)

		for marker in depiction.build_markers(d):
			if marker == null or marker.is_empty():
				continue
			var target_id := int(marker.get(Keys.TARGET_ID, 0))
			var marker_kind: StringName = marker.get(StatusDepiction.MARKER_KIND, &"")
			if target_id <= 0 or marker_kind == &"":
				continue
			var view := battle_view.get_combatant(target_id)
			if view != null:
				view.set_status_depiction_marker(depiction_key, marker_kind, true)

	for command in depiction.build_fx_commands(d):
		_apply_status_depiction_fx_command(command)


func _apply_status_depiction_fx_command(command: Dictionary) -> void:
	if command == null or command.is_empty() or battle_view == null or battle_view.fx_manager == null:
		return

	var op: StringName = command.get(StatusDepiction.FX_OP, &"")
	match op:
		StatusDepiction.FX_OP_ENSURE_PERSISTENT:
			var target_id := int(command.get(Keys.TARGET_ID, 0))
			var target := battle_view.get_combatant(target_id)
			if target == null:
				return
			battle_view.fx_manager.ensure_on_combatant(
				String(command.get(StatusDepiction.FX_KEY, "")),
				target,
				command.get(StatusDepiction.FX_ID, &""),
				float(command.get(StatusDepiction.FX_FADE_IN, 0.06)),
				float(command.get(StatusDepiction.FX_SCALE, 1.05)),
				float(command.get(StatusDepiction.FX_CENTER_Y_RATIO, 0.5))
			)
		StatusDepiction.FX_OP_CLEAR_PERSISTENT:
			battle_view.fx_manager.clear_key(
				String(command.get(StatusDepiction.FX_KEY, "")),
				float(command.get(StatusDepiction.FX_FADE_OUT, 0.06))
			)


func _clear_status_depiction_key_from_views(depiction_key: String) -> void:
	if battle_view == null or depiction_key.is_empty():
		return
	for view in battle_view.get_all_combatant_views():
		if view != null and is_instance_valid(view):
			view.clear_status_depiction_marker_key(depiction_key)


func _clear_status_depiction_prefix_from_views(depiction_prefix: String) -> void:
	if battle_view == null or depiction_prefix.is_empty():
		return
	for view in battle_view.get_all_combatant_views():
		if view != null and is_instance_valid(view):
			view.clear_status_depiction_marker_prefix(depiction_prefix)


func _on_set_intent(e: EventPackage) -> void:
	var d := _data(e)
	var cid := int(d.get(Keys.ACTOR_ID, e.event.active_actor_id))
	var planned_idx := int(d.get(Keys.PLANNED_IDX, -1))
	var icon_uid := String(d.get(Keys.INTENT_ICON_UID, ""))
	var icon_ranged_uid := String(d.get(Keys.INTENT_ICON_RANGED_UID, ""))
	var intent_text := String(d.get(Keys.INTENT_TEXT, ""))
	var tooltip_text := String(d.get(Keys.TOOLTIP_TEXT, ""))
	var is_ranged := bool(d.get(Keys.IS_RANGED, false))
	var intent_text_color: Color = d.get(Keys.INTENT_TEXT_COLOR, Color.WHITE)

	var cv := battle_view.get_combatant(cid)
	if cv == null:
		return

	if cv.intent_container != null:
		cv.intent_container.apply_intent(planned_idx, icon_uid, icon_ranged_uid, is_ranged, intent_text, tooltip_text, intent_text_color)


func _on_removed(e: EventPackage) -> void:
	var dead_id := _target_id(e)
	if dead_id <= 0:
		return

	_play_vfx_payloads_from_event(e)

	var g := _group_index(e)
	var after_order := _after_order(e)
	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)

	var v := battle_view.get_combatant(dead_id)
	if v != null:
		v.is_alive = false
		if battle_view.fx_manager != null:
			battle_view.fx_manager.clear_for_combatant(v)
		v.queue_free()

	battle_view.combatants_by_cid.erase(dead_id)

	if g >= 0 and !after_order.is_empty():
		_apply_group_order(g, after_order, true)


func _on_removal_windup(e: EventPackage) -> void:
	var removed_id := _target_id(e)
	if removed_id <= 0:
		return

	var target := battle_view.get_combatant(removed_id)
	if target == null:
		return

	var o = RemovalWindupOrder.new()
	o.duration = e.duration
	o.target_id = removed_id
	o.removal_type = int(_removal_type(e))
	o.to_black = true
	o.black_amount = 1.0
	o.shrink = 0.96
	o.slump_px = 10.0

	target.play_removal_windup(o)


func _on_removal_followthrough(e: EventPackage) -> void:
	_play_vfx_payloads_from_event(e)

	var removal_type := _removal_type(e)
	var dur := maxf(e.duration, 0.01)
	if int(removal_type) == int(Removal.Type.FADE):
		var faded_id := _target_id(e)
		var faded_group := _group_index(e)
		var faded_group_view: GroupView = battle_view.friendly_group if faded_group == 0 else battle_view.enemy_group
		if faded_group_view != null:
			faded_group_view.unregister_cid(faded_id)

		var faded_view := battle_view.get_combatant(faded_id)
		if faded_view != null:
			faded_view.play_removal_followthrough(removal_type, dur)
			faded_view.is_alive = false
			if battle_view.fx_manager != null:
				battle_view.fx_manager.clear_for_combatant(faded_view, dur)
			if battle_view.clock != null:
				await battle_view.clock.wait_seconds(dur)
			if is_instance_valid(faded_view):
				faded_view.queue_free()
		battle_view.combatants_by_cid.erase(faded_id)
		return

	var dead_id := _target_id(e)
	var g := _group_index(e)

	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)

	var dead_view := battle_view.get_combatant(dead_id)
	if dead_view == null:
		return

	dead_view.play_removal_followthrough(removal_type, dur)
	dead_view.is_alive = false
	if battle_view.fx_manager != null:
		battle_view.fx_manager.clear_for_combatant(dead_view, dur)

	if battle_view.clock != null:
		await battle_view.clock.wait_seconds(dur)
	else:
		push_warning("BattleEventDirector._on_removal_followthrough(): missing battle clock; skipping cleanup delay")

	if is_instance_valid(dead_view):
		dead_view.queue_free()

	battle_view.combatants_by_cid.erase(dead_id)


func _play_vfx_payloads_from_event(e: EventPackage) -> void:
	if e == null or e.event == null or battle_view == null:
		return

	var d := _data(e)
	var payloads = d.get(Keys.VFX_PAYLOADS, [])
	if !(payloads is Array):
		return

	for raw_payload in payloads:
		if !(raw_payload is Dictionary):
			continue
		var payload := raw_payload as Dictionary
		_play_vfx_payload_sound(payload)

		var fx_id: StringName = payload.get(Keys.VFX_ID, &"")
		if fx_id == &"" or battle_view.fx_manager == null:
			continue

		var anchor_view := _resolve_vfx_anchor_view(payload, d)
		var global_pos := _resolve_vfx_global_position(payload, d, anchor_view)
		var scale := float(payload.get(Keys.VFX_SCALE, 1.0))
		var size := _resolve_vfx_size(payload, anchor_view, scale)
		battle_view.fx_manager.play_at_global_position(fx_id, global_pos, size)


func _play_vfx_payload_sound(payload: Dictionary) -> void:
	var sound := _resolve_vfx_payload_sound(String(payload.get(Keys.VFX_SOUND, "")))
	if sound != null:
		SFXPlayer.play(sound)


func _resolve_vfx_payload_sound(sound_ref: String) -> Sound:
	if sound_ref.is_empty():
		return null
	if _vfx_payload_sound_cache.has(sound_ref):
		return _vfx_payload_sound_cache[sound_ref] as Sound

	var sound := load(sound_ref) as Sound
	if sound == null:
		push_warning("BattleEventDirector._resolve_vfx_payload_sound(): failed to load VFX payload sound %s" % sound_ref)
		return null

	_vfx_payload_sound_cache[sound_ref] = sound
	return sound


func _resolve_vfx_anchor_view(payload: Dictionary, event_data: Dictionary) -> CombatantView:
	var anchor: StringName = payload.get(Keys.VFX_ANCHOR, Keys.VFX_ANCHOR_TARGET)
	var id := 0
	match anchor:
		Keys.VFX_ANCHOR_SOURCE:
			id = int(event_data.get(Keys.SOURCE_ID, 0))
		_:
			id = int(event_data.get(Keys.TARGET_ID, 0))
	return battle_view.get_combatant(id) if id > 0 else null


func _resolve_vfx_global_position(payload: Dictionary, _event_data: Dictionary, anchor_view: CombatantView) -> Vector2:
	var anchor: StringName = payload.get(Keys.VFX_ANCHOR, Keys.VFX_ANCHOR_TARGET)
	if anchor == Keys.VFX_ANCHOR_EVENT_POSITION:
		return _coerce_vector2(payload.get(Keys.VFX_POSITION, Vector2.ZERO))

	var offset := _coerce_vector2(payload.get(Keys.VFX_OFFSET, Vector2.ZERO))
	if anchor_view == null:
		return offset

	var height := float(anchor_view.get_visual_height_px())
	return anchor_view.global_position + Vector2(0, -height * 0.5) + offset


func _resolve_vfx_size(payload: Dictionary, anchor_view: CombatantView, scale: float) -> Vector2:
	var explicit_size := _coerce_vector2(payload.get(Keys.VFX_SIZE, Vector2.ZERO))
	if explicit_size.x > 0.0 and explicit_size.y > 0.0:
		return explicit_size * maxf(scale, 0.01)

	var height := 180.0
	if anchor_view != null:
		height = float(anchor_view.get_visual_height_px())
	var side := maxf(height * maxf(scale, 0.01), 1.0)
	return Vector2(side, side)


func _coerce_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		var v := value as Vector2i
		return Vector2(v.x, v.y)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _on_discard_requested(e: EventPackage) -> void:
	if e == null:
		return

	var ctx := DiscardContext.new()
	var sim_host: SimHost = battle_view.sim_host if battle_view != null else null
	var api := sim_host.get_main_api() if sim_host != null else null
	var req := api.get_pending_discard() if api != null else null

	# Only live pending discard requests should open selection UI.
	# If this event is replayed after the request has already been resolved,
	# falling back to logged payload would reopen a stale discard flow.
	if req == null:
		return

	ctx.request_id = int(req.request_id)
	ctx.source_id = int(req.source_id)
	ctx.amount = int(req.amount)
	ctx.card_uid = String(req.card_uid)

	ctx.on_done = func(chosen_uids: Array[String]) -> void:
		if sim_host == null:
			push_warning("DiscardContext.on_done: missing sim_host")
			return
		if api == null:
			push_warning("DiscardContext.on_done: missing sim api")
			return
		api.resolve_player_discard(chosen_uids)
		if req == null or req.card_ctx == null or req.card_ctx.runtime == null:
			push_warning("DiscardContext.on_done: missing live discard request/card context")
			return
		req.card_ctx.runtime.resume_async_action(req.card_ctx, int(req.action_index), {
			Keys.CHOSEN_UIDS: chosen_uids,
		})

	var interaction := DiscardInteractionContext.new()
	interaction.discard_ctx = ctx
	Events.request_interaction.emit(interaction)


func _on_draw_cards(e: EventPackage) -> void:
	if e == null or e.event == null:
		#print("[TRACE battle_event_director] _on_draw_cards: missing event package")
		return

	var d := _data(e)
	var ctx = d.get(Keys.DRAW_CONTEXT, null) as DrawContext
	if ctx == null:
		ctx = DrawContext.new()
		ctx.source_id = int(d.get(Keys.SOURCE_ID, 0))
		ctx.amount = int(d.get(Keys.AMOUNT, 0))
		ctx.reason = String(d.get(Keys.REASON, ""))
		ctx.disable_until_next_player_turn = bool(d.get(Keys.DISABLE_UNTIL_NEXT_PLAYER_TURN, false))

	#print("[TRACE battle_event_director] DRAW_CARDS seq=%d source_id=%d amount=%d reason=%s" % [
		#int(e.event.seq),
		#int(ctx.source_id),
		#int(ctx.amount),
		#String(ctx.reason)
	#])
	Events.request_draw_cards.emit(ctx)

func _on_discard_cards(e: EventPackage) -> void:
	if e == null or e.event == null:
		return

	var d := _data(e)
	var ctx = d.get(Keys.DISCARD_CONTEXT, null) as DiscardContext
	if ctx == null:
		ctx = DiscardContext.new()
		ctx.source_id = int(d.get(Keys.SOURCE_ID, 0))
		ctx.amount = int(d.get(Keys.AMOUNT, 0))
		ctx.card_uid = String(d.get(Keys.CARD_UID, ""))
		ctx.reason = String(d.get(Keys.REASON, ""))

	Events.execute_discard_cards.emit(ctx)


func _on_summon_windup(e: EventPackage) -> void:
	var v := _ensure_summon_view(e, false)
	if v == null:
		return

	_place_summon_for_windup(e, v)


func _on_summon_followthrough(e: EventPackage) -> void:
	var summoned_id := int(_data(e).get(Keys.SUMMONED_ID, 0))

	var v := battle_view.get_combatant(summoned_id)
	if v != null:
		v.is_alive = true

	var caster := battle_view.get_combatant(_source_id(e))
	if caster != null:
		caster.clear_strike_pose(e.duration)


func _on_summoned(e: EventPackage) -> void:
	var d := _data(e)
	var v := _ensure_summon_view(e, true)
	if v == null:
		return

	if v.character_art != null:
		var c := v.character_art.modulate
		c.a = 1.0
		v.character_art.modulate = c

	var summon_sound := _resolve_summon_sound(String(d.get(Keys.SUMMON_SOUND, "")))
	if summon_sound != null:
		SFXPlayer.play(summon_sound)

	_play_default_summon_pop_fx(v)

	var summoned_id := int(d.get(Keys.SUMMONED_ID, 0))
	var card_uid := String(d.get(Keys.CARD_UID, ""))
	if summoned_id > 0 and !card_uid.is_empty():
		Events.summon_reserve_card_acquired.emit(summoned_id, card_uid)


func _play_default_summon_pop_fx(v: CombatantView) -> void:
	if v == null or !is_instance_valid(v):
		return
	v.play_summon_pop_scale(0.20)
	if battle_view != null and battle_view.fx_manager != null:
		#                                                                   fade_in, hold, fade_out, scale.
		battle_view.fx_manager.play_on_combatant(v, FxLibrary.FX_LIGHT_RADIAL, 0.1, 0.25, 0.5, 2)
		battle_view.fx_manager.play_on_combatant(v, FxLibrary.FX_RIPPLE, 0.1, 0.01, 0.12, 1.5)


func _on_summon_reserve_released(e: EventPackage) -> void:
	var d := _data(e)
	var summoned_id := int(d.get(Keys.SUMMONED_ID, 0))
	var card_uid := String(d.get(Keys.CARD_UID, ""))
	var overload_mod := int(d.get(Keys.OVERLOAD_MOD, 0))
	var destination := int(d.get(Keys.RESERVE_RELEASE_DESTINATION, CardMoveContext.BinKind.DISCARD_PILE))
	var overload_override := int(d.get(Keys.OVERLOAD_OVERRIDE, -1))
	if summoned_id <= 0 or card_uid == "":
		return
	var v := battle_view.get_combatant(summoned_id)
	if v != null:
		v.set_has_summon_reserve_card(false)
	Events.summon_reserve_card_released.emit(
		summoned_id,
		card_uid,
		overload_mod,
		destination,
		overload_override
	)

func _on_victory(e: EventPackage) -> void:
	var _d := _data(e)
	#var reason := String(d.get(Keys.REASON, ""))
	# Optional: stop playback visuals immediately if you want.
	# if battle_view != null: battle_view.stop_playback()
	Events.request_victory.emit()

func _on_defeat(e: EventPackage) -> void:
	var _d := _data(e)
	#var reason := String(d.get(Keys.REASON, ""))
	# Optional: stop playback visuals immediately if you want.
	# if battle_view != null: battle_view.stop_playback()
	Events.request_defeat.emit()

func _on_scope_begin(e: EventPackage) -> void:
	var d := _data(e)
	var scope_kind := int(d.get(Keys.SCOPE_KIND, e.event.scope_kind if e != null and e.event != null else -1))
	if scope_kind != int(Scope.Kind.CARD):
		return

	var scope_id := int(d.get(Keys.SCOPE_ID, 0))
	var actor_id := int(d.get(Keys.ACTOR_ID, 0))
	Events.card_scope_view_started.emit(scope_id, actor_id)


func _on_scope_end(e: EventPackage) -> void:
	var d := _data(e)
	var scope_kind := int(d.get(Keys.SCOPE_KIND, e.event.scope_kind if e != null and e.event != null else -1))
	if scope_kind != int(Scope.Kind.CARD):
		return

	var scope_id := int(d.get(Keys.SCOPE_ID, 0))
	var actor_id := int(d.get(Keys.ACTOR_ID, 0))
	Events.card_scope_view_finished.emit(scope_id, actor_id)

func _on_mana(e: EventPackage) -> void:
	var _d := _data(e)
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

	if o.attack_mode == Attack.Mode.RANGED:
		print("VIEW ranged strike windup projectile uid/path: ", o.projectile_scene_path)

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
	if slice.strike != null:
		o.chained_from_previous = bool(slice.strike.chained_from_previous)
		o.origin_strike_index = int(slice.strike.origin_strike_index)
		o.chain_source_target_id = int(slice.strike.chain_source_target_id)
		o.has_chain_continuation = _slice_strike_has_chain_continuation(slice)

	# target selection for THIS strike
	o.target_ids = _coerce_int_array(slice.get_target_ids())

	if o.attack_mode == Attack.Mode.RANGED:
		print("VIEW ranged strike windup projectile uid/path: ", o.projectile_scene_path)

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
		o.chained_from_previous = slice.strike.chained_from_previous if slice.strike != null else false
		o.origin_strike_index = slice.strike.origin_strike_index if slice.strike != null else -1
		o.chain_source_target_id = slice.strike.chain_source_target_id if slice.strike != null else 0
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
		for h in slice.strike.recoil_hits:
			if h == null:
				continue
			var recoil_target := battle_view.get_combatant(int(h.target_id))
			if recoil_target != null:
				recoil_target.play_received_hit_from_hitinfo(h, duration)


func _slice_strike_has_chain_continuation(slice: StrikeFollowthroughSlice) -> bool:
	if slice == null or slice.attack == null:
		return false
	var next_index := int(slice.strike_index) + 1
	if next_index < 0 or next_index >= slice.attack.strikes.size():
		return false
	var next_strike: StrikePresentationInfo = slice.attack.strikes[next_index]
	if next_strike == null or !next_strike.chained_from_previous:
		return false
	return int(next_strike.origin_strike_index) == int(slice.strike_index)

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

		PresentationOrder.Kind.RANGED_CLEAVE:
			var o4c := order as RangedFirePresentationOrder
			if o4c != null:
				bits.append("i=%d" % int(o4c.strike_index))
				bits.append("n=%d" % int(o4c.strikes_total))
				bits.append("hits=%d" % int(o4c.total_hit_count))
				bits.append("lethal=%s" % str(bool(o4c.has_lethal)))
				if o4c.projectile_scene_path != "":
					bits.append("proj=%s" % o4c.projectile_scene_path.get_file())

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
				bits.append("stk=%d" % int(o8.stacks))

		PresentationOrder.Kind.REMOVAL:
			var o9 = order
			if o9 != null:
				bits.append("t=%d" % int(o9.target_id))
				bits.append("g=%d" % int(o9.group_index))
				bits.append("type=%s" % String(Removal.Type.keys()[int(o9.removal_type)]))
				bits.append("after=%s" % str(o9.after_order_ids))
		PresentationOrder.Kind.GROUP_LAYOUT:
			var og := order as GroupLayoutPresentationOrder
			if og != null:
				bits.append("g=%d" % int(og.group_index))
				bits.append("order=%s" % str(og.order_ids))
				bits.append("anim=%s" % str(bool(og.animate)))

	return " ".join(bits)
