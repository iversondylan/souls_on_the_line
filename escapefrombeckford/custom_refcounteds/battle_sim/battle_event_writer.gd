# battle_event_writer.gd
class_name BattleEventWriter extends RefCounted

var log: BattleEventLog
var scopes: BattleScopeManager

var turn_id: int = 0
var group_index: int = -1
var active_actor_id: int = 0

var allow_unscoped_events: bool = false

func _init(_log: BattleEventLog, _scopes: BattleScopeManager) -> void:
	log = _log
	scopes = _scopes

func set_turn_context(_turn_id: int, _group_index: int, _actor_id: int) -> void:
	turn_id = _turn_id
	group_index = _group_index
	active_actor_id = _actor_id

func _append(type: int, data: Dictionary = {}) -> int:
	if log == null:
		return 0

	var sid := (scopes.current_scope_id() if scopes != null else 0)
	if sid == 0 and !allow_unscoped_events:
		push_warning("BattleEventWriter: attempted to append event with no active scope. type=%s" % str(type))
		return 0

	var e := BattleEvent.new(type)
	e.turn_id = turn_id
	e.group_index = group_index
	e.active_actor_id = active_actor_id

	if scopes != null:
		e.scope_id = scopes.current_scope_id()
		e.parent_scope_id = scopes.current_parent_scope_id()
		e.scope_kind = scopes.current_scope_kind()

	e.data = data

	var seq := log.append(e)
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

func scope_begin(kind: int, label: String = "", actor_id: int = 0, extra := {}) -> int:
	if scopes == null:
		push_warning("BattleEventWriter: scope_begin without scopes")
		return 0

	var f := scopes.push(kind, label, actor_id, group_index, turn_id)

	if actor_id > 0:
		active_actor_id = actor_id
	
	var data := {
		Keys.SCOPE_ID: f.id,
		Keys.PARENT_SCOPE_ID: f.parent_id,
		Keys.SCOPE_KIND: f.kind,
		Keys.SCOPE_LABEL: f.label,
		Keys.ACTOR_ID: f.actor_id,
		Keys.GROUP_INDEX: f.group_index,
		Keys.TURN_ID: f.turn_id,
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.SCOPE_BEGIN, data)

func scope_end() -> int:
	if scopes == null:
		push_warning("BattleEventWriter: scope_end without scopes")
		return 0

	var f := scopes.pop()
	if f == null:
		push_warning("BattleEventWriter: scope_end with empty stack")
		return 0
	
	var data := {
		Keys.SCOPE_ID: f.id,
		Keys.PARENT_SCOPE_ID: f.parent_id,
		Keys.SCOPE_KIND: f.kind,
		Keys.SCOPE_LABEL: f.label,
		Keys.ACTOR_ID: f.actor_id,
	}
	
	return _append_manual(BattleEvent.Type.SCOPE_END, f.id, f.parent_id, f.kind, data)

# -------------------------
# “Structural” timeline markers (these scale into animation)
# -------------------------

func emit_spawned(spawned_id: int, group_idx: int, insert_index: int, after_order: PackedInt32Array, proto: String = "", spec: Dictionary = {}) -> int:
	var data := {
		Keys.SPAWNED_ID: int(spawned_id),
		Keys.GROUP_INDEX: int(group_idx),
		Keys.INSERT_INDEX: int(insert_index),
		Keys.AFTER_ORDER_IDS: after_order,
		Keys.PROTO: String(proto),
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
	return _append(BattleEvent.Type.DEBUG, { # if you later add ARCANA_PROC type, switch to it
		Keys.PROC: int(proc),
		Keys.TURN_ID: int(turn_id),
		Keys.GROUP_INDEX: int(group_index),
	})

# -------------------------
# Gameplay events
# -------------------------

func emit_card_played(ctx: CardActionContextSim) -> int:
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
	}

	if Keys.LOG_ENUM_STRINGS:
		var card_type_s := int(CardData.CardType.keys()[card_type_i] if card_type_i >= 0 and card_type_i < CardData.CardType.size() else -1)
		var target_type_s := int(CardData.TargetType.keys()[target_type_i] if target_type_i >= 0 and target_type_i < CardData.TargetType.size() else -1)
		data[Keys.CARD_TYPE_S] = card_type_s
		data[Keys.CARD_TARGET_TYPE_S] = target_type_s

	return _append(BattleEvent.Type.CARD_PLAYED, data)

func emit_damage_applied(source_id: int, target_id: int, base: int, final_amount: int, armor_dmg: int, hp_dmg: int, lethal: bool, before_health: int, after_health: int) -> int:
	return _append(BattleEvent.Type.DAMAGE_APPLIED, {
		Keys.SOURCE_ID: int(source_id),
		Keys.TARGET_ID: int(target_id),
		Keys.BASE_AMOUNT: int(base),
		Keys.FINAL_AMOUNT: int(final_amount),
		Keys.ARMOR_DAMAGE: int(armor_dmg),
		Keys.HEALTH_DAMAGE: int(hp_dmg),
		Keys.WAS_LETHAL: bool(lethal),
		Keys.BEFORE_HEALTH: int(before_health),
		Keys.AFTER_HEALTH: int(after_health),
	})

func emit_targeted(attacker_id: int, target_ids: Array[int], attack_mode: int, strike_index: int, extra := {}) -> void:
	var data := {
		Keys.SOURCE_ID: attacker_id,
		Keys.TARGET_IDS: target_ids,
		Keys.ATTACK_MODE: attack_mode,
		Keys.STRIKE_INDEX: strike_index
	}
	for k in extra.keys():
		data[k] = extra[k]
	return _append(BattleEvent.Type.TARGETED, data)

func emit_attack_prep(attacker_id: int, target_ids: Array[int], attack_mode: int, target_type: int, strikes: int) -> int:
	return _append(BattleEvent.Type.ATTACK_PREP, {
		Keys.SOURCE_ID: int(attacker_id),
		Keys.TARGET_IDS: target_ids, # <-- REQUIRED BY YOU
		Keys.ATTACK_MODE: int(attack_mode),
		Keys.TARGET_TYPE: int(target_type),
		Keys.STRIKES: int(strikes),
	})

func emit_attack_wrapup(attacker_id: int, attack_mode: int, target_type: int, strikes: int) -> int:
	return _append(BattleEvent.Type.ATTACK_WRAPUP, {
		Keys.SOURCE_ID: int(attacker_id),
		Keys.ATTACK_MODE: int(attack_mode),
		Keys.TARGET_TYPE: int(target_type),
		Keys.STRIKES: int(strikes),
	})


func emit_strike_windup(attacker_id: int, target_ids: Array[int], attack_mode: int, target_type: int, strike_index: int) -> int:
	return _append(BattleEvent.Type.STRIKE_WINDUP, {
		Keys.SOURCE_ID: int(attacker_id),
		Keys.TARGET_IDS: target_ids,
		Keys.ATTACK_MODE: int(attack_mode),
		Keys.TARGET_TYPE: int(target_type),
		Keys.STRIKE_INDEX: int(strike_index),
	})

func emit_strike_followthrough(attacker_id: int, target_ids: Array[int], attack_mode: int, target_type: int, strike_index: int) -> int:
	return _append(BattleEvent.Type.STRIKE_FOLLOWTHROUGH, {
		Keys.SOURCE_ID: int(attacker_id),
		Keys.TARGET_IDS: target_ids,
		Keys.ATTACK_MODE: int(attack_mode),
		Keys.TARGET_TYPE: int(target_type),
		Keys.STRIKE_INDEX: int(strike_index),
	})

func emit_death(combat_id: int, after_order: PackedInt32Array,  reason: String = "") -> int:
	return _append(BattleEvent.Type.DEBUG, {
		Keys.TARGET_ID: int(combat_id),
		Keys.DEATH_REASON: String(reason),
		Keys.AFTER_ORDER_IDS: after_order,
	})

func emit_summoned(summoned_id: int, group_idx: int, insert_index: int, after_order: PackedInt32Array, proto: String = "", spec: Dictionary = {}) -> int:
	var data := {
		Keys.SUMMONED_ID: int(summoned_id),
		Keys.GROUP_INDEX: int(group_idx),
		Keys.INSERT_INDEX: int(insert_index),
		Keys.AFTER_ORDER_IDS: after_order,
		Keys.PROTO: String(proto),
	}
	if spec != null and !spec.is_empty():
		data[Keys.SUMMON_SPEC] = spec
	return _append(BattleEvent.Type.SUMMONED, data)

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

func emit_status_applied(source_id: int, target_id: int, status_id: StringName, intensity: int, duration: int) -> int:
	return _append(BattleEvent.Type.STATUS_APPLIED, {
		Keys.SOURCE_ID: int(source_id),
		Keys.TARGET_ID: int(target_id),
		Keys.STATUS_ID: status_id,
		Keys.INTENSITY: int(intensity),
		Keys.DURATION: int(duration),
	})

func emit_status_removed(source_id: int, target_id: int, status_id: StringName, intensity: int, removed_all: bool) -> int:
	return _append(BattleEvent.Type.STATUS_REMOVED, {
		Keys.SOURCE_ID: int(source_id),
		Keys.TARGET_ID: int(target_id),
		Keys.STATUS_ID: status_id,
		Keys.INTENSITY: int(intensity),
		Keys.REMOVED_ALL: bool(removed_all),
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

func _append_manual(type: int, scope_id: int, parent_scope_id: int, scope_kind: int, data: Dictionary = {}) -> int:
	if log == null:
		return 0

	var e := BattleEvent.new(type)
	e.turn_id = turn_id
	e.group_index = group_index
	e.active_actor_id = active_actor_id

	e.scope_id = scope_id
	e.parent_scope_id = parent_scope_id
	e.scope_kind = scope_kind

	e.data = data

	var seq := log.append(e)
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
