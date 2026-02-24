# battle_event_writer.gd

class_name BattleEventWriter extends RefCounted

var log: BattleEventLog
var scopes: BattleScopeManager

# Turn context (set by SIM orchestrator / turn engine driver)
var turn_id: int = 0
var group_index: int = -1
var active_actor_id: int = 0

# Policy: allow events without a scope?
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

	print("battle_event_writer.gd _append() seq=%d type=%d scope=%d kind=%s data=%s" % [seq, e.type, e.scope_id, String(e.scope_kind), str(e.data)])
	return seq

# -------------------------
# Scope helpers (emit begin/end markers)
# -------------------------

func scope_begin(kind: StringName, label: String = "", actor_id: int = 0) -> int:
	if scopes == null:
		push_warning("battle_event_writer.gd scope_begin() without scopes")
		return 0

	var f := scopes.push(kind, label, actor_id, group_index, turn_id)

	# Update active_actor_id if this scope is actor-centric (optional policy)
	if actor_id > 0:
		active_actor_id = actor_id

	return _append(BattleEvent.Type.SCOPE_BEGIN, {
		&"scope_id": f.id,
		&"parent_scope_id": f.parent_id,
		&"kind": f.kind,
		&"label": f.label,
		&"actor_id": f.actor_id,
		&"group_index": f.group_index,
		&"turn_id": f.turn_id,
	})

func scope_end() -> int:
	if scopes == null:
		push_warning("BattleEventWriter: scope_end without scopes")
		return 0

	var f := scopes.pop()
	if f == null:
		push_warning("BattleEventWriter: scope_end with empty stack")
		return 0

	# After pop, writer stamps events to new current scope; but SCOPE_END should reference the ended scope.
	# So we emit with explicit ids in data.
	return _append(BattleEvent.Type.SCOPE_END, {
		&"scope_id": f.id,
		&"parent_scope_id": f.parent_id,
		&"kind": f.kind,
		&"label": f.label,
		&"actor_id": f.actor_id,
	})

# -------------------------
# Common battle events (you’ll expand these)
# -------------------------

func emit_card_played(ctx: CardActionContextSim) -> int:
	if ctx.card_data == null:
		return 0
	ctx.card_data.ensure_uid()
	return _append(BattleEvent.Type.CARD_PLAYED, {
		&"card_uid": ctx.card_data.uid,
		&"card_name": ctx.card_data.name,
		&"card_type": CardData.CardType.keys()[int(ctx.card_data.card_type)],
		&"source_id": ctx.source_id,
		&"target_type": CardData.TargetType.keys()[int(ctx.card_data.target_type)],
		&"targets": ctx.affected_ids,
		&"insert_index": ctx.insert_index
	})


func emit_damage_applied(source_id: int, target_id: int, base: int, final_amount: int, armor_dmg: int, hp_dmg: int, lethal: bool) -> int:
	return _append(BattleEvent.Type.DAMAGE_APPLIED, {
		&"source_id": source_id,
		&"target_id": target_id,
		&"base": base,
		&"amount": final_amount,
		&"armor_damage": armor_dmg,
		&"health_damage": hp_dmg,
		&"was_lethal": lethal,
	})


## Do I need to change the return output here to include something from spec?
func emit_summoned(summoned_id: int, group_idx: int, insert_index: int, proto: String = "", spec: Dictionary = {}) -> int:
	return _append(BattleEvent.Type.SUMMONED, {
		&"summoned_id": summoned_id,
		&"group_index": group_idx,
		&"insert_index": insert_index,
		&"proto": proto,
	})

func emit_card_mutated(card: CardData, reason: String = "", delta: Dictionary = {}) -> int:
	if card == null:
		return 0
	card.ensure_uid()
	return _append(BattleEvent.Type.CARD_MUTATED, {
		&"card_uid": card.uid,
		&"card_name": card.name,
		&"reason": reason,
		&"delta": delta,
	})

func emit_status_applied(source_id: int, target_id: int, status_id: StringName, stacks_delta: int, duration: int) -> int:
	return _append(BattleEvent.Type.STATUS_APPLIED, {
		&"source_id": int(source_id),
		&"target_id": int(target_id),
		&"status_id": status_id,
		&"stacks_delta": int(stacks_delta),
		&"duration": int(duration),
	})

func emit_status_removed(source_id: int, target_id: int, status_id: StringName, stacks_delta: int, removed_all: bool) -> int:
	return _append(BattleEvent.Type.STATUS_REMOVED, {
		&"source_id": int(source_id),
		&"target_id": int(target_id),
		&"status_id": status_id,
		&"stacks_delta": int(stacks_delta),
		&"removed_all": bool(removed_all),
	})
