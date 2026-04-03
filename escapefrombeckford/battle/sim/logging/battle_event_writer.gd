# battle_event_writer.gd

class_name BattleEventWriter extends RefCounted

var sink: EventSink
var scopes: BattleScopeManager

var turn_id: int = 0
var group_index: int = -1
var active_actor_id: int = 0

var allow_unscoped_events: bool = false

var _beat_marker_types := {
	BattleEvent.Type.ARCANUM_PROC: true,
	BattleEvent.Type.STRIKE: true,
	BattleEvent.Type.CLEAVE: true,
	BattleEvent.Type.SUMMONED: true,
	BattleEvent.Type.DIED: true,
	BattleEvent.Type.FADED: true,
}

func _init(_sink: EventSink, _scopes: BattleScopeManager) -> void:
	sink = _sink
	scopes = _scopes

func set_turn_context(_turn_id: int, _group_index: int, _actor_id: int) -> void:
	turn_id = _turn_id
	group_index = _group_index
	active_actor_id = _actor_id

func _append(type: int, data: Dictionary = {}) -> int:
	if sink == null:
		return -1

	var sid := (scopes.current_scope_id() if scopes != null else 0)
	if sid == 0 and !allow_unscoped_events:
		push_warning("BattleEventWriter: attempted to append event with no active scope. type=%s" % str(type))
		return -1

	var e := BattleEvent.new(type)
	e.turn_id = turn_id
	e.group_index = group_index
	e.active_actor_id = active_actor_id
	if _beat_marker_types.get(type, false):
		#print("battle_event_writer.gd _append() making ", BattleEvent.Type.keys()[type], " as defines_beat")
		e.defines_beat = true

	if scopes != null:
		e.scope_id = scopes.current_scope_id()
		e.parent_scope_id = scopes.current_parent_scope_id()
		e.scope_kind = scopes.current_scope_kind()

	e.data = data

	var seq := sink.append(e)
	#print("EVT seq=%d type=%s scope=%d kind=%s ctx(t=%d g=%d a=%d) data=%s" % [
		#seq,
		#BattleEvent.Type.keys()[int(e.type)] if int(e.type) >= 0 and int(e.type) < BattleEvent.Type.size() else str(e.type),
		#e.scope_id,
		#Scope.Kind.keys()[e.scope_kind],
		#int(e.turn_id),
		#int(e.group_index),
		#int(e.active_actor_id),
		#str(e.data)
	#])
	return seq

# -------------------------
# Scope helpers
# -------------------------

func scope_begin(kind: int, label: String = "", actor_id: int = 0, extra := {}) -> ScopeHandle:
	if scopes == null:
		_scope_failure("BattleEventWriter.scope_begin(): missing scope manager")
		return null

	var handle := scopes.push(kind, label, actor_id, group_index, turn_id)
	if handle == null:
		_scope_failure("BattleEventWriter.scope_begin(): failed to create scope handle")
		return null

	if actor_id > 0:
		active_actor_id = actor_id
	
	var data := {
		Keys.SCOPE_ID: handle.scope_id,
		Keys.PARENT_SCOPE_ID: handle.parent_scope_id,
		Keys.SCOPE_KIND: handle.kind,
		Keys.SCOPE_LABEL: handle.label,
		Keys.ACTOR_ID: handle.actor_id,
		Keys.GROUP_INDEX: handle.group_index,
		Keys.TURN_ID: handle.turn_id,
	}
	for k in extra.keys():
		data[k] = extra[k]
	var seq := _append(BattleEvent.Type.SCOPE_BEGIN, data)
	if seq < 0:
		scopes.close(handle)
		_scope_failure("BattleEventWriter.scope_begin(): failed to append SCOPE_BEGIN id=%d" % int(handle.scope_id))
		return null
	return handle

func scope_end(handle: ScopeHandle) -> int:
	if scopes == null:
		_scope_failure("BattleEventWriter.scope_end(): missing scope manager")
		return 0

	var closed := scopes.close(handle)
	if closed == null:
		_scope_failure(scopes.last_error_message if scopes != null else "BattleEventWriter.scope_end(): failed to close scope")
		return 0
	
	var data := {
		Keys.SCOPE_ID: closed.scope_id,
		Keys.PARENT_SCOPE_ID: closed.parent_scope_id,
		Keys.SCOPE_KIND: closed.kind,
		Keys.SCOPE_LABEL: closed.label,
		Keys.ACTOR_ID: closed.actor_id,
	}
	
	return _append_manual(BattleEvent.Type.SCOPE_END, closed.scope_id, closed.parent_scope_id, closed.kind, data)

# -------------------------
# “Structural” timeline markers (these scale into animation)
# -------------------------

func emit_spawned(spawned_id: int, group_idx: int, insert_index: int, after_order: PackedInt32Array, proto: String = "", spec: Dictionary = {}, is_player := false) -> int:
	var data := {
		Keys.SPAWNED_ID: int(spawned_id),
		Keys.GROUP_INDEX: int(group_idx),
		Keys.INSERT_INDEX: int(insert_index),
		Keys.AFTER_ORDER_IDS: after_order,
		Keys.PROTO: String(proto),
		Keys.IS_PLAYER: is_player,
	}
	if spec != null and !spec.is_empty():
		data[Keys.SUMMON_SPEC] = spec
	return _append(BattleEvent.Type.SPAWNED, data)

func emit_formation_set(g0: PackedInt32Array, g1: PackedInt32Array, player_id: int) -> int:
	return _append(BattleEvent.Type.FORMATION_SET, {
		Keys.PLAYER_ID: int(player_id),
		Keys.GROUP_0: g0,
		Keys.GROUP_1: g1,
	})

func emit_group_turn_begin(group_idx: int) -> int:
	return _append(BattleEvent.Type.TURN_GROUP_BEGIN, {
		Keys.GROUP_INDEX: int(group_idx),
		Keys.TURN_ID: int(turn_id),
	})

func emit_group_turn_end(group_idx: int) -> int:
	return _append(BattleEvent.Type.TURN_GROUP_END, {
		Keys.GROUP_INDEX: int(group_idx),
		Keys.TURN_ID: int(turn_id),
	})

func emit_turn_status(active_id: int, pending_ids: PackedInt32Array, group_idx: int, player_id: int) -> int:
	return _append(BattleEvent.Type.TURN_STATUS, {
		Keys.ACTIVE_ID: int(active_id),
		Keys.PENDING_IDS: pending_ids,
		Keys.GROUP_INDEX: int(group_idx),
		Keys.PLAYER_ID: int(player_id),
		Keys.TURN_ID: int(turn_id),
	})

func emit_actor_begin(actor_id: int) -> int:
	return _append(BattleEvent.Type.ACTOR_BEGIN, {
		Keys.ACTOR_ID: int(actor_id),
		Keys.GROUP_INDEX: int(group_index),
		Keys.TURN_ID: int(turn_id),
	})

func emit_actor_end(actor_id: int) -> int:
	return _append(BattleEvent.Type.ACTOR_END, {
		Keys.ACTOR_ID: int(actor_id),
		Keys.GROUP_INDEX: int(group_index),
		Keys.TURN_ID: int(turn_id),
	})

func emit_arcana_proc(proc: int) -> int:
	return _append(BattleEvent.Type.ARCANA_PROC, { # if you later add ARCANA_PROC type, switch to it
		Keys.PROC: int(proc),
		Keys.TURN_ID: int(turn_id),
		Keys.GROUP_INDEX: int(group_index),
	})

func emit_arcanum_proc(source_id: int, arcanum_id: StringName, proc: int, extra := {}) -> int:
	var data := {
		Keys.SOURCE_ID: int(source_id),
		Keys.ARCANUM_ID: arcanum_id,
		Keys.PROC: int(proc),
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.ARCANUM_PROC, data)

func emit_card_played_ctx(ctx: CardContext) -> int:
	if ctx == null or ctx.card_data == null:
		return 0

	ctx.card_data.ensure_uid()

	var card_type_i := int(ctx.card_data.card_type)
	var target_type_i := int(ctx.card_data.target_type)

	var data := {
		Keys.CARD_UID: ctx.card_data.uid,
		Keys.CARD_NAME: ctx.card_data.name,
		Keys.CARD_TYPE_I: card_type_i,
		Keys.CARD_TARGET_TYPE_I: target_type_i,
		Keys.SOURCE_ID: int(ctx.source_id),
		Keys.TARGETS: ctx.affected_ids,
		Keys.INSERT_INDEX: int(ctx.insert_index),
		Keys.SUMMONED_IDS: ctx.summoned_ids,
	}

	return _append(BattleEvent.Type.CARD_PLAYED, data)

func emit_mana(
	source_id: int,
	before_mana: int,
	after_mana: int,
	before_max_mana: int,
	after_max_mana: int,
	reason: String = "",
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(source_id),
		Keys.BEFORE_MANA: int(before_mana),
		Keys.AFTER_MANA: int(after_mana),
		Keys.BEFORE_MAX_MANA: int(before_max_mana),
		Keys.AFTER_MAX_MANA: int(after_max_mana),
		Keys.REASON: String(reason),
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.MANA, data)

func emit_damage_applied(
	source_id: int,
	target_id: int,
	base: int,
	base_banish: int,
	final_amount: int,
	display_amount: int,
	banish_amount: int,
	applied_banish_amount: int,
	armor_dmg: int,
	hp_dmg: int,
	lethal: bool,
	before_health: int,
	after_health: int,
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(source_id),
		Keys.TARGET_ID: int(target_id),
		Keys.BASE_AMOUNT: int(base),
		Keys.BASE_BANISH_AMOUNT: int(base_banish),
		Keys.FINAL_AMOUNT: int(final_amount),
		Keys.DISPLAY_AMOUNT: int(display_amount),
		Keys.BANISH_AMOUNT: int(banish_amount),
		Keys.APPLIED_BANISH_AMOUNT: int(applied_banish_amount),
		Keys.ARMOR_DAMAGE: int(armor_dmg),
		Keys.HEALTH_DAMAGE: int(hp_dmg),
		Keys.WAS_LETHAL: bool(lethal),
		Keys.BEFORE_HEALTH: int(before_health),
		Keys.AFTER_HEALTH: int(after_health),
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.DAMAGE_APPLIED, data)

func emit_heal_applied(
	source_id: int,
	target_id: int,
	before_health: int,
	after_health: int,
	flat_amount: int,
	of_total: float,
	of_missing: float,
	healed_amount: int,
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(source_id),
		Keys.TARGET_ID: int(target_id),
		Keys.BEFORE_HEALTH: int(before_health),
		Keys.AFTER_HEALTH: int(after_health),
		Keys.FLAT_AMOUNT: int(flat_amount),
		Keys.OF_TOTAL: float(of_total),
		Keys.OF_MISSING: float(of_missing),
		Keys.HEALED_AMOUNT: int(healed_amount),
	}

	for k in extra.keys():
		data[k] = extra[k]

	return _append(BattleEvent.Type.HEAL_APPLIED, data)

func emit_change_max_health(
	source_id: int,
	target_id: int,
	before_max_health: int,
	after_max_health: int,
	before_health: int,
	after_health: int,
	amount: int,
	change_health_relative: bool,
	reason: String = "",
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(source_id),
		Keys.TARGET_ID: int(target_id),
		Keys.BEFORE_MAX_HEALTH: int(before_max_health),
		Keys.AFTER_MAX_HEALTH: int(after_max_health),
		Keys.BEFORE_HEALTH: int(before_health),
		Keys.AFTER_HEALTH: int(after_health),
		Keys.AMOUNT: int(amount),
		Keys.CHANGE_HEALTH_RELATIVE: bool(change_health_relative),
		Keys.REASON: String(reason),
	}

	for k in extra.keys():
		data[k] = extra[k]

	return _append(BattleEvent.Type.CHANGE_MAX_HEALTH, data)


func emit_modify_battle_card(
	card_uid: String,
	modified_fields: Dictionary,
	reason: String = "",
	extra := {}
) -> int:
	var data := {
		Keys.CARD_UID: String(card_uid),
		Keys.MODIFIED_FIELDS: modified_fields.duplicate(true) if modified_fields != null else {},
		Keys.REASON: String(reason),
	}

	for k in extra.keys():
		data[k] = extra[k]

	return _append(BattleEvent.Type.MODIFY_BATTLE_CARD, data)

func emit_strike(
	attacker_id: int,
	target_ids: Array[int],
	attack_mode: int,
	target_type: int,
	strike_index: int,
	strikes_total: int = 1,
	projectile_scene: String = "",
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(attacker_id),
		Keys.TARGET_IDS: target_ids,
		Keys.ATTACK_MODE: int(attack_mode),
		Keys.TARGET_TYPE: int(target_type),
		Keys.STRIKE_INDEX: int(strike_index),
		Keys.STRIKES: int(strikes_total),
	}
	if projectile_scene != "":
		data[Keys.PROJECTILE_SCENE] = String(projectile_scene)
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.STRIKE, data)

func emit_cleave(
	attacker_id: int,
	target_ids: Array[int],
	attack_mode: int,
	target_type: int,
	strike_index: int,
	strikes_total: int = 1,
	projectile_scene: String = "",
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(attacker_id),
		Keys.TARGET_IDS: target_ids,
		Keys.ATTACK_MODE: int(attack_mode),
		Keys.TARGET_TYPE: int(target_type),
		Keys.STRIKE_INDEX: int(strike_index),
		Keys.STRIKES: int(strikes_total),
	}
	if projectile_scene != "":
		data[Keys.PROJECTILE_SCENE] = String(projectile_scene)
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.CLEAVE, data)

func emit_summoned(
	source_id: int,
	summoned_id: int,
	group_idx: int,
	insert_index: int,
	before_order: PackedInt32Array,
	after_order: PackedInt32Array,
	proto: String = "",
	spec: Dictionary = {},
	reason: String = "",
	bound_card_uid: String = "",
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(source_id), # NEW
		Keys.SUMMONED_ID: int(summoned_id),
		Keys.GROUP_INDEX: int(group_idx),
		Keys.INSERT_INDEX: int(insert_index),
		Keys.BEFORE_ORDER_IDS: before_order,
		Keys.AFTER_ORDER_IDS: after_order,
	}
	if proto != "":
		data[Keys.PROTO] = String(proto)
	if spec != null and !spec.is_empty():
		data[Keys.SUMMON_SPEC] = spec
	if reason != "":
		data[Keys.REASON] = String(reason)
	if bound_card_uid != "":
		data[Keys.CARD_UID] = String(bound_card_uid)
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.SUMMONED, data)

func emit_status(
	source_id: int,
	target_id: int,
	status_id: StringName,
	op: int,
	intensity: int = 0,
	duration: int = 0,
	extra := {},
) -> int:
	
	# enum OP {APPLY, REMOVE, CHANGE}
	# APPLY: add new status only
	# REMOVE: remove a status entirely
	# CHANGE: increase or decrease INTENSITY/DURATION...
	# ...either by re-application (add intensity/duration) or a direct
	# change effect (add/remove intensity/duration stacks)
	var status_op := 0
	if Status.OP.values().has(op):
		status_op = op
	var data := {
		Keys.SOURCE_ID: int(source_id),
		Keys.TARGET_ID: int(target_id),
		Keys.TARGET_IDS: PackedInt32Array([int(target_id)]),
		Keys.STATUS_ID: status_id,
		Keys.OP: status_op,
		Keys.INTENSITY: int(intensity),
		Keys.DURATION: int(duration),
		Keys.STATUS_PENDING: bool(extra.get(Keys.STATUS_PENDING, false)),
		Keys.REASON: String(extra.get(Keys.REASON, "")),
		Keys.STATUS_PRESENTATION_HINT: StringName(extra.get(Keys.STATUS_PRESENTATION_HINT, &"standalone")),
	}
	
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.STATUS, data)

func emit_status_apply(
	source_id: int,
	target_id: int,
	status_id: StringName,
	intensity: int,
	duration: int,
	extra := {}
) -> int:
	return emit_status(source_id, target_id, status_id, int(Status.OP.APPLY), intensity, duration, extra)

func emit_status_change(
	source_id: int,
	target_id: int,
	status_id: StringName,
	delta_intensity: int,
	delta_duration: int,
	extra := {}
) -> int:
	return emit_status(source_id, target_id, status_id, int(Status.OP.CHANGE), delta_intensity, delta_duration, extra)

func emit_status_remove(
	source_id: int,
	target_id: int,
	status_id: StringName,
	extra := {}
) -> int:
	return emit_status(source_id, target_id, status_id, int(Status.OP.REMOVE), 0, 0, extra)

func emit_died(
	killer_id: int,
	dead_id: int,
	group_idx: int,
	before_order: PackedInt32Array,
	after_order: PackedInt32Array,
	reason: String = "",
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(killer_id),
		Keys.TARGET_ID: int(dead_id),
		Keys.GROUP_INDEX: int(group_idx),
		Keys.BEFORE_ORDER_IDS: before_order,
		Keys.AFTER_ORDER_IDS: after_order,
		Keys.DEATH_REASON: String(reason),
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.DIED, data)

func emit_faded(
	target_id: int,
	group_idx: int,
	before_order: PackedInt32Array,
	after_order: PackedInt32Array,
	reason: String = "",
	extra := {}
) -> int:
	var data := {
		Keys.TARGET_ID: int(target_id),
		Keys.GROUP_INDEX: int(group_idx),
		Keys.BEFORE_ORDER_IDS: before_order,
		Keys.AFTER_ORDER_IDS: after_order,
		Keys.REASON: String(reason),
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.FADED, data)

func emit_summon_reserve_released(summoned_id: int, card_uid: String, reason: String = "") -> int:
	return _append(BattleEvent.Type.SUMMON_RESERVE_RELEASED, {
		Keys.SUMMONED_ID: int(summoned_id),
		Keys.CARD_UID: String(card_uid),
		Keys.REASON: String(reason),
	})

func emit_victory(source_id: int = 0, reason: String = "") -> int:
	return _append(BattleEvent.Type.VICTORY, {
		Keys.SOURCE_ID: int(source_id),
		Keys.REASON: String(reason),
		Keys.TURN_ID: int(turn_id),
		Keys.GROUP_INDEX: int(group_index),
	})

func emit_defeat(source_id: int = 0, reason: String = "") -> int:
	return _append(BattleEvent.Type.DEFEAT, {
		Keys.SOURCE_ID: int(source_id),
		Keys.REASON: String(reason),
		Keys.TURN_ID: int(turn_id),
		Keys.GROUP_INDEX: int(group_index),
	})

func emit_moved(actor_id: int, move_type: int, before_order: PackedInt32Array, after_order: PackedInt32Array, extra: Dictionary = {}) -> int:
	var data := {
		Keys.ACTOR_ID: int(actor_id),
		Keys.MOVE_TYPE: int(move_type),
		Keys.BEFORE_ORDER_IDS: before_order,
		Keys.AFTER_ORDER_IDS: after_order,
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.MOVED, data)

func emit_set_intent(
	actor_id: int,
	planned_idx: int,
	icon_uid: String = "",
	icon_ranged_uid: String = "",
	intent_text: String = "",
	tooltip_text: String = "",
	is_ranged: bool = false,
	intent_text_color: Color = Color.WHITE
) -> int:
	return _append(BattleEvent.Type.SET_INTENT, {
		Keys.ACTOR_ID: int(actor_id),
		Keys.PLANNED_IDX: int(planned_idx),
		Keys.INTENT_ICON_UID: String(icon_uid),
		Keys.INTENT_ICON_RANGED_UID: String(icon_ranged_uid),
		Keys.INTENT_TEXT: String(intent_text),
		Keys.TOOLTIP_TEXT: String(tooltip_text),
		Keys.IS_RANGED: bool(is_ranged),
		Keys.INTENT_TEXT_COLOR: intent_text_color,
	})

func emit_card_mutated(card: CardData, reason: String = "", delta: Dictionary = {}) -> int:
	if card == null:
		return 0
	card.ensure_uid()
	return _append(BattleEvent.Type.CARD_MUTATED, {
		Keys.CARD_UID: card.uid,
		Keys.CARD_NAME: card.name,
		Keys.REASON: String(reason),
		Keys.DELTA: delta,
	})

func emit_player_input_reached(player_id: int) -> void:
	return _append(BattleEvent.Type.PLAYER_INPUT_REACHED, {
		Keys.ACTOR_ID: int(player_id),
	})

func emit_end_turn_pressed(player_id: int) -> void:
	return _append(BattleEvent.Type.END_TURN_PRESSED, {
		Keys.ACTOR_ID: int(player_id),
	})

func emit_discard_requested(req: DiscardRequest) -> int:
	return _append(BattleEvent.Type.DISCARD_REQUESTED, {
		Keys.REQUEST_ID: int(req.request_id),
		Keys.SOURCE_ID: int(req.source_id),
		Keys.AMOUNT: int(req.amount),
		Keys.REASON: String(req.reason),
		Keys.CARD_UID: String(req.card_uid),
	})

func emit_discard_resolved(req: DiscardRequest, chosen_uids: Array[String]) -> int:
	return _append(BattleEvent.Type.DISCARD_RESOLVED, {
		Keys.REQUEST_ID: int(req.request_id),
		Keys.SOURCE_ID: int(req.source_id),
		Keys.AMOUNT: int(req.amount),
		Keys.REASON: String(req.reason),
		Keys.CARD_UID: String(req.card_uid),
		Keys.CHOSEN_UIDS: chosen_uids,
	})


func emit_draw_cards(
	source_id: int,
	amount: int,
	reason: String = "",
	disable_until_next_player_turn: bool = false,
	extra := {}
) -> int:
	var data := {
		Keys.SOURCE_ID: int(source_id),
		Keys.AMOUNT: int(amount),
		Keys.REASON: String(reason),
		Keys.DISABLE_UNTIL_NEXT_PLAYER_TURN: bool(disable_until_next_player_turn),
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.DRAW_CARDS, data)



func _append_manual(type: int, scope_id: int, parent_scope_id: int, scope_kind: int, data: Dictionary = {}) -> int:
	if sink == null:
		return -1

	var e := BattleEvent.new(type)
	e.turn_id = turn_id
	e.group_index = group_index
	e.active_actor_id = active_actor_id

	e.scope_id = scope_id
	e.parent_scope_id = parent_scope_id
	e.scope_kind = scope_kind

	e.data = data

	var seq := sink.append(e)
	#print("EVT seq=%d type=%s scope=%d kind=%s ctx(t=%d g=%d a=%d) data=%s" % [
		#seq,
		#BattleEvent.Type.keys()[int(e.type)] if int(e.type) >= 0 and int(e.type) < BattleEvent.Type.size() else str(e.type),
		#e.scope_id,
		#Scope.Kind.keys()[e.scope_kind],
		#int(e.turn_id),
		#int(e.group_index),
		#int(e.active_actor_id),
		#str(e.data)
	#])
	return seq

func _scope_failure(message: String) -> void:
	var text := String(message)
	push_error(text)
	if OS.is_debug_build():
		assert(false, text) #Assertion failed: BattleEventWriter.scope_begin(): failed to append SCOPE_BEGIN id=1
