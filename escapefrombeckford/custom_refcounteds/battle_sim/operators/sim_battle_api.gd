# sim_battle_api.gd

class_name SimBattleAPI extends RefCounted

# ============================================================================
# SimBattleAPI
# ----------------------------------------------------------------------------
# Responsibilities:
# - read/query battle state
# - perform atomic state mutations
# - emit events for those mutations
# - request dirtying/checkpoint work
#
# Explicitly NOT responsible for:
# - turn/group lifecycle orchestration
# - intent lifecycle orchestration
# - status proto classification rules
#
# Those belong in:
# - SimRuntime
# - ActionLifecycleSystem
# - SimStatusSystem
# ============================================================================

const FRIENDLY := 0
const ENEMY := 1

var state: BattleState
var checkpoint_processor: CheckpointProcessor

# Runtime callbacks assigned externally.
var on_summoned: Callable = Callable()		# (summoned_id: int, group_index: int) -> void
var on_unit_removed: Callable = Callable()	# (combat_id: int, group_index: int, reason: String) -> void
var on_urgent_planning_requested: Callable = Callable()
# Transitional: should ultimately live in dedicated player/input state.
var pending_discard: DiscardRequest = null

var scopes: BattleScopeManager
var writer: BattleEventWriter


# ============================================================================
# Init
# ============================================================================

func _init(_state: BattleState) -> void:
	state = _state


# ============================================================================
# Basic queries
# ============================================================================

func is_alive(combat_id: int) -> bool:
	return state != null and state.is_alive(int(combat_id))


func get_group(combat_id: int) -> int:
	if state == null:
		return -1
	var u := state.get_unit(int(combat_id))
	return int(u.team) if u != null else -1


func get_team(combat_id: int) -> int:
	# team == group for now
	return get_group(combat_id)


func get_opposing_group(group_index: int) -> int:
	return 1 - clampi(int(group_index), 0, 1)


func get_combatants_in_group(group_index: int, allow_dead := false) -> Array[int]:
	var ids: Array[int] = []
	if state == null:
		return ids

	var gi := clampi(int(group_index), 0, 1)
	for id in state.groups[gi].order:
		if allow_dead or state.is_alive(int(id)):
			ids.append(int(id))
	return ids


func get_n_combatants_in_group(group_index: int, allow_dead := false) -> int:
	return get_combatants_in_group(group_index, allow_dead).size()


func get_front_combatant_id(group_index: int) -> int:
	var ids := get_combatants_in_group(group_index, false)
	return int(ids[0]) if ids.size() > 0 else 0


func get_enemies_of(combat_id: int) -> Array[int]:
	var g := get_group(combat_id)
	if g == -1:
		return []
	return get_combatants_in_group(get_opposing_group(g), false)


func get_allies_of(combat_id: int) -> Array[int]:
	var g := get_group(combat_id)
	if g == -1:
		return []

	var ids := get_combatants_in_group(g, false)
	ids.erase(int(combat_id))
	return ids


func get_rank_in_group(combat_id: int) -> int:
	if state == null:
		return -1

	var g := get_group(combat_id)
	if g == -1:
		return -1

	return state.groups[g].index_of(int(combat_id))


func get_player_id() -> int:
	if state == null or state.groups == null or state.groups.size() <= FRIENDLY:
		return -1
	return int(state.groups[FRIENDLY].player_id)


func get_player_pos_delta(combat_id: int) -> int:
	var player_id := get_player_id()
	if player_id <= 0:
		return 0

	var my_rank := get_rank_in_group(int(combat_id))
	var player_rank := get_rank_in_group(player_id)
	if my_rank == -1 or player_rank == -1:
		return 0

	return my_rank - player_rank


func has_status(combat_id: int, status_id: StringName) -> bool:
	if state == null:
		return false

	var u := state.get_unit(int(combat_id))
	if u == null or !u.is_alive():
		return false

	return u.statuses.has(status_id)


func get_status_intensity(combat_id: int, status_id: StringName) -> int:
	if state == null:
		return -1

	var u := state.get_unit(int(combat_id))
	if u == null or !u.is_alive() or u.statuses == null:
		return -1

	var stack: StatusStack = u.statuses.get_status_stack(status_id)
	if stack == null:
		return -1

	return int(stack.intensity)


func find_marked_ranged_redirect_target(attacker_id: int) -> int:
	for id in get_enemies_of(int(attacker_id)):
		if has_status(int(id), Keys.STATUS_MARKED):
			return int(id)
	return 0


func get_targets_for_attack_sequence(ai_ctx) -> Array:
	if ai_ctx == null:
		return []

	var attacker_id := int(ai_ctx.cid) if ai_ctx and ("cid" in ai_ctx) else 0
	if attacker_id <= 0 and ai_ctx.combatant:
		attacker_id = int(ai_ctx.combatant.combat_id)
	if attacker_id <= 0 and ai_ctx.combatant_data:
		attacker_id = int(ai_ctx.combatant_data.combat_id)

	if attacker_id <= 0:
		return []

	return AttackTargeting.get_target_ids(self, attacker_id, ai_ctx.params)

# ============================================================================
# Card / mana queries
# ============================================================================


func can_pay_cost(cost: int) -> bool:
	if state == null or state.resource == null:
		return false
	return int(cost) <= int(state.resource.mana)


func can_pay_card(card: CardData) -> bool:
	if card == null:
		return false
	return can_pay_cost(int(card.get_total_cost()))

func get_mana() -> int:
	if state == null or state.resource == null:
		return 0
	return int(state.resource.mana)


func get_max_mana() -> int:
	if state == null or state.resource == null:
		return 0
	return int(state.resource.max_mana)


func has_pending_discard() -> bool:
	return state != null and state.resource != null and state.resource.pending_discard != null

# ============================================================================
# Dirtying / checkpoint requests
# ============================================================================

func _request_replan(cid: int) -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_replan(int(cid))
		return

	if state == null:
		return

	var u: CombatantState = state.get_unit(int(cid))
	if u == null:
		return

	ActionPlanner.ensure_ai_state_initialized(u)
	u.ai_state[&"replan_dirty"] = true

func _request_replan_all() -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_replan_all()
		return

	if state == null:
		return

	for k in state.units.keys():
		_request_replan(int(k))

func _request_intent_refresh(cid: int) -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_intent_refresh(int(cid))
		return

	if state == null:
		return

	var u: CombatantState = state.get_unit(int(cid))
	if u == null:
		return

	ActionPlanner.ensure_ai_state_initialized(u)
	u.ai_state[&"intent_dirty"] = true


func _request_intent_refresh_all() -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_intent_refresh_all()
		return

	if state == null:
		return

	for k in state.units.keys():
		_request_intent_refresh(int(k))


func _request_immediate_planning_flush_if_needed(target_id: int, proto: Status) -> void:
	if proto == null:
		return
	if !proto.affects_intent_legality():
		return

	# Dirtiness should already be requested before this point,
	# but make sure the target definitely gets both.
	_request_replan(int(target_id))
	_request_intent_refresh(int(target_id))

	if on_urgent_planning_requested.is_valid():
		on_urgent_planning_requested.call()

func _request_turn_order_rebuild() -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_turn_order_rebuild()


func _on_status_changed(cid: int) -> void:
	_request_replan(int(cid))


func _request_intent_refresh_targets_for_aura(_source_id: int, _proto: Status) -> void:
	# Conservative and correct for now.
	_request_intent_refresh_all()


# ============================================================================
# Core action entry points
# ============================================================================

func resolve_attack(ctx: NPCAIContext) -> bool:
	return SimAttackRunner.run(self, ctx)


func resolve_damage_immediate(ctx: DamageContext) -> int:
	if ctx == null or state == null:
		return 0

	if int(ctx.base_amount) <= 0:
		ctx.amount = 0
		return 0

	if !state.is_alive(int(ctx.target_id)):
		ctx.amount = 0
		return 0

	ctx.phase = DamageContext.Phase.PRE_MODIFIERS
	ctx.amount = int(ctx.base_amount)

	ctx.amount = SimModifierResolver.get_modified_value(
		state,
		int(ctx.amount),
		ctx.deal_modifier_type,
		int(ctx.source_id)
	)
	ctx.amount = SimModifierResolver.get_modified_value(
		state,
		int(ctx.amount),
		ctx.take_modifier_type,
		int(ctx.target_id)
	)

	ctx.amount = maxi(int(ctx.amount), 0)
	ctx.phase = DamageContext.Phase.POST_MODIFIERS

	var tgt: CombatantState = state.get_unit(int(ctx.target_id))
	if tgt == null:
		ctx.amount = 0
		return 0

	var remaining := int(ctx.amount)
	var before_health := int(tgt.health)

	var armor_damage := mini(remaining, maxi(int(tgt.armor), 0))
	tgt.armor = int(tgt.armor) - armor_damage
	remaining -= armor_damage

	var health_damage := mini(remaining, maxi(int(tgt.health), 0))
	tgt.health = int(tgt.health) - health_damage
	remaining -= health_damage

	ctx.armor_damage = armor_damage
	ctx.health_damage = health_damage
	ctx.was_lethal = (int(tgt.health) <= 0)
	ctx.phase = DamageContext.Phase.APPLIED

	if writer != null:
		writer.emit_damage_applied(
			int(ctx.source_id),
			int(ctx.target_id),
			int(ctx.base_amount),
			int(ctx.amount),
			int(ctx.armor_damage),
			int(ctx.health_damage),
			bool(ctx.was_lethal),
			int(before_health),
			int(tgt.health),
		)

	on_damage_applied(ctx)

	if bool(ctx.was_lethal):
		resolve_death(int(ctx.target_id), "damage", int(ctx.source_id))

	return int(ctx.amount)


func resolve_death(combat_id: int, reason := "", killer_id: int = 0) -> void:
	if state == null or int(combat_id) <= 0:
		return

	var u: CombatantState = state.get_unit(int(combat_id))
	if u == null or !u.alive:
		return

	_maybe_release_soulbound_reserve(u, "fade:" + String(reason))
	SimDeathRunner.run(self, int(combat_id), int(killer_id), String(reason))


func resolve_move(ctx: MoveContext) -> void:
	if ctx == null or state == null:
		return
	if int(ctx.actor_id) <= 0:
		return

	var u := state.get_unit(int(ctx.actor_id))
	if u == null or !u.is_alive():
		return

	var g := int(u.team)
	if g < 0:
		return

	ctx.before_order_ids = PackedInt32Array(state.groups[g].order)

	match ctx.move_type:
		MoveContext.MoveType.MOVE_TO_FRONT:
			_move_id_to_index(g, int(ctx.actor_id), 0)
		MoveContext.MoveType.MOVE_TO_BACK:
			_move_id_to_index(g, int(ctx.actor_id), state.groups[g].order.size() - 1)
		MoveContext.MoveType.INSERT_AT_INDEX:
			_move_id_to_index(g, int(ctx.actor_id), int(ctx.index))
		MoveContext.MoveType.SWAP_WITH_TARGET:
			if int(ctx.target_id) > 0:
				_swap_ids(g, int(ctx.actor_id), int(ctx.target_id))
		_:
			pass

	ctx.after_order_ids = PackedInt32Array(state.groups[g].order)
	_request_turn_order_rebuild()

	if writer != null:
		writer.scope_begin(Scope.Kind.MOVE, "actor=%d" % int(ctx.actor_id), int(ctx.actor_id))

		var extra := {}
		if int(ctx.target_id) > 0:
			extra[Keys.TARGET_ID] = int(ctx.target_id)
		if int(ctx.index) >= 0:
			extra[Keys.TO_INDEX] = int(ctx.index)

		writer.emit_moved(
			int(ctx.actor_id),
			int(ctx.move_type),
			ctx.before_order_ids,
			ctx.after_order_ids,
			extra
		)
		writer.scope_end()


func apply_status(ctx: StatusContext) -> void:
	if ctx == null or state == null:
		return
	if int(ctx.target_id) <= 0:
		return
	if ctx.status_id == &"":
		return

	var u := state.get_unit(int(ctx.target_id))
	if u == null or !u.is_alive():
		return

	if int(ctx.intensity) == 0:
		ctx.intensity = 1

	var changed := u.statuses.add_or_reapply_ctx(ctx)
	ctx.applied = changed or (ctx.op == Status.OP.APPLY)

	if writer != null and (ctx.op == Status.OP.APPLY or changed):
		writer.emit_status(
			int(ctx.source_id),
			int(ctx.target_id),
			ctx.status_id,
			int(ctx.op),
			int(ctx.intensity),
			int(ctx.duration),
			{
				Keys.DELTA_INTENSITY: int(ctx.delta_intensity),
				Keys.DELTA_DURATION: int(ctx.delta_duration),
				Keys.BEFORE_INTENSITY: int(ctx.before_intensity),
				Keys.BEFORE_DURATION: int(ctx.before_duration),
				Keys.AFTER_INTENSITY: int(ctx.after_intensity),
				Keys.AFTER_DURATION: int(ctx.after_duration),
			}
		)

	_rebuild_modifier_cache_for(int(ctx.target_id))

	var status_ctx := SimStatusSystem.make_context(
		self,
		int(ctx.target_id),
		u.statuses.get_status_stack(ctx.status_id)
	)
	if status_ctx != null and status_ctx.proto != null:
		status_ctx.proto.on_apply(status_ctx, ctx)

	var proto := SimStatusSystem.get_proto(self, ctx.status_id)

	if SimStatusSystem.is_aura_proto(proto):
		_request_intent_refresh_targets_for_aura(int(ctx.target_id), proto)
	else:
		_request_intent_refresh(int(ctx.target_id))

	_on_status_changed(int(ctx.target_id))

	_request_immediate_planning_flush_if_needed(int(ctx.target_id), proto)


func remove_status(ctx: StatusContext) -> void:
	if ctx == null or state == null:
		return
	if int(ctx.target_id) <= 0:
		return
	if ctx.status_id == &"":
		return

	var u := state.get_unit(int(ctx.target_id))
	if u == null:
		return

	var proto := SimStatusSystem.get_proto(self, ctx.status_id)
	var old_stack: StatusStack = u.statuses.get_status_stack(ctx.status_id)

	var before_i := 0
	var before_d := 0
	if old_stack != null:
		before_i = int(old_stack.intensity)
		before_d = int(old_stack.duration)

	var status_ctx := SimStatusSystem.make_context(self, int(ctx.target_id), old_stack)
	u.statuses.remove_ctx(ctx)

	if writer != null:
		writer.emit_status(
			int(ctx.source_id),
			int(ctx.target_id),
			ctx.status_id,
			int(Status.OP.REMOVE),
			0,
			0,
			{
				Keys.BEFORE_INTENSITY: before_i,
				Keys.BEFORE_DURATION: before_d,
				Keys.AFTER_INTENSITY: 0,
				Keys.AFTER_DURATION: 0,
				Keys.DELTA_INTENSITY: -before_i,
				Keys.DELTA_DURATION: -before_d,
			}
		)

	_rebuild_modifier_cache_for(int(ctx.target_id))

	if status_ctx != null and status_ctx.proto != null:
		status_ctx.proto.on_remove(status_ctx, ctx)

	if SimStatusSystem.is_aura_proto(proto):
		_request_intent_refresh_targets_for_aura(int(ctx.target_id), proto)
	else:
		_request_intent_refresh(int(ctx.target_id))

	_on_status_changed(int(ctx.target_id))

	_request_immediate_planning_flush_if_needed(int(ctx.target_id), proto)


func fade_unit(combat_id: int, reason: String = "fade") -> void:
	if state == null:
		return

	var u: CombatantState = state.get_unit(int(combat_id))
	if u == null or !u.alive:
		return

	_maybe_release_soulbound_reserve(u, "fade:" + String(reason))

	var g := int(u.team)
	var before := PackedInt32Array(state.groups[g].order)

	if writer != null:
		writer.scope_begin(Scope.Kind.FADE, "fade_unit", int(combat_id))

	u.alive = false
	if g != -1:
		state.groups[g].remove(int(combat_id))

	if on_unit_removed.is_valid():
		on_unit_removed.call(int(combat_id), int(g), "fade:" + String(reason))

	var after_order_ids := PackedInt32Array(state.groups[g].order) if g != -1 else PackedInt32Array()
	_request_turn_order_rebuild()

	if writer != null:
		writer.emit_faded(int(combat_id), int(g), before, after_order_ids, String(reason))
		writer.scope_end()


# ============================================================================
# Spawn / summon
# ============================================================================

func spawn_from_data(combatant_data: CombatantData, group_index: int, insert_index: int = -1, is_player := false) -> int:
	if combatant_data == null or state == null:
		return 0

	var g := clampi(int(group_index), 0, 1)
	var id := state.alloc_id()

	if is_player:
		state.groups[FRIENDLY].player_id = id

	var u := _make_unit_from_combatant_data(combatant_data, id, g, is_player)
	state.add_unit(u, g, int(insert_index))
	_request_turn_order_rebuild()

	if writer != null:
		var proto := String(u.data_proto_path)
		var spec := _make_spawn_spec_from_data(combatant_data, u)
		var after_order_ids := PackedInt32Array(state.groups[g].order)
		writer.emit_spawned(id, g, int(insert_index), after_order_ids, proto, spec, bool(is_player))

	return id


func summon(ctx: SummonContext) -> void:
	if ctx == null or state == null:
		return
	if ctx.summon_data == null:
		push_warning("SimBattleAPI.summon: missing summon_data")
		return

	var g := clampi(int(ctx.group_index), 0, 1)
	var source_id := int(ctx.source_id) if ("source_id" in ctx) else 0

	var windup_order := ctx.windup_order_ids
	if windup_order == null or windup_order.is_empty():
		windup_order = PackedInt32Array(state.groups[g].order)

	var id := state.alloc_id()
	ctx.summon_data.combat_id = id

	var u := _make_unit_from_combatant_data(ctx.summon_data, id, g, false)
	u.bound_card_uid = String(ctx.bound_card_uid)
	u.mortality = int(ctx.mortality)
	u.type = CombatantView.Type.ALLY if g == 0 else CombatantView.Type.ENEMY

	state.add_unit(u, g, int(ctx.insert_index))
	_request_turn_order_rebuild()

	if writer != null:
		var spec := _make_spawn_spec_from_data(ctx.summon_data, u)
		var after_order_ids := PackedInt32Array(state.groups[g].order)
		writer.emit_summoned(
			int(source_id),
			int(id),
			int(g),
			int(ctx.insert_index),
			windup_order,
			after_order_ids,
			u.data_proto_path,
			spec,
			ctx.reason,
			ctx.bound_card_uid
		)

	ctx.summoned_id = id

	if on_summoned.is_valid():
		on_summoned.call(int(id), int(g))

	_request_replan(int(id))
	_request_intent_refresh(int(id))


func count_summons_in_group(group_index: int) -> int:
	if state == null:
		return 0

	var gi := clampi(int(group_index), 0, 1)
	var n := 0

	for id in state.groups[gi].order:
		var u: CombatantState = state.get_unit(int(id))
		if u == null or !u.is_alive():
			continue
		if u.combatant_data != null and int(u.combatant_data.team) == 1:
			n += 1

	return n


func count_soulbound_in_group(group_index: int) -> int:
	if state == null:
		return 0

	var gi := clampi(int(group_index), 0, 1)
	var n := 0

	for id in state.groups[gi].order:
		var u: CombatantState = state.get_unit(int(id))
		if u == null or !u.is_alive():
			continue
		if int(u.mortality) == int(CombatantView.Mortality.SOULBOUND):
			n += 1

	return n


# ============================================================================
# Card / discard
# ============================================================================

func on_card_played(ctx: CardActionContextSim) -> void:
	if ctx == null or ctx.card_data == null or writer == null:
		return
	if ctx.emitted_card_played:
		return

	ctx.emitted_card_played = true
	ctx.card_data.ensure_uid()

	writer.scope_begin(
		Scope.Kind.CARD,
		"uid=%s %s" % [str(ctx.card_data.uid), String(ctx.card_data.name)],
		int(ctx.source_id)
	)
	writer.emit_card_played(ctx)


func on_card_finished(_ctx: CardActionContextSim) -> void:
	if writer != null:
		writer.scope_end()


func request_player_discard(req: DiscardRequest) -> void:
	if req == null or state == null or state.resource == null:
		return

	if state.resource.pending_discard != null:
		push_warning("SimBattleAPI.request_player_discard(): discard already pending")
		return

	state.resource.pending_discard = req

	if writer != null:
		writer.emit_discard_requested(req)


func resolve_player_discard(selected_card_uids: Array[String]) -> void:
	if state == null or state.resource == null or state.resource.pending_discard == null:
		push_warning("SimBattleAPI.resolve_player_discard(): no pending discard")
		return

	var req := state.resource.pending_discard
	state.resource.pending_discard = null

	if writer != null:
		writer.emit_discard_resolved(req, selected_card_uids)

# ============================================================================
# Shared resource mutations
# ============================================================================

func set_mana(new_mana: int, reason: String = "") -> void:
	if state == null or state.resource == null:
		return

	var before_mana := int(state.resource.mana)
	var before_max_mana := int(state.resource.max_mana)

	state.resource.mana = clampi(int(new_mana), 0, int(state.resource.max_mana))

	var after_mana := int(state.resource.mana)
	var after_max_mana := int(state.resource.max_mana)

	if writer != null and (before_mana != after_mana or before_max_mana != after_max_mana):
		writer.emit_mana(
			get_player_id(),
			before_mana,
			after_mana,
			before_max_mana,
			after_max_mana,
			reason
		)


func set_max_mana(new_max_mana: int, refill := false, reason: String = "") -> void:
	if state == null or state.resource == null:
		return

	var before_mana := int(state.resource.mana)
	var before_max_mana := int(state.resource.max_mana)

	state.resource.max_mana = maxi(int(new_max_mana), 0)
	if refill:
		state.resource.mana = int(state.resource.max_mana)
	else:
		state.resource.mana = mini(int(state.resource.mana), int(state.resource.max_mana))

	var after_mana := int(state.resource.mana)
	var after_max_mana := int(state.resource.max_mana)

	if writer != null and (before_mana != after_mana or before_max_mana != after_max_mana):
		writer.emit_mana(
			get_player_id(),
			before_mana,
			after_mana,
			before_max_mana,
			after_max_mana,
			reason
		)


func gain_mana(amount: int, reason: String = "") -> void:
	if state == null or state.resource == null:
		return
	if int(amount) == 0:
		return
	set_mana(int(state.resource.mana) + int(amount), reason)


func refresh_mana_for_group_turn(group_index: int) -> void:
	if state == null or state.resource == null:
		return

	# Only refresh on friendly group turn start.
	if int(group_index) != FRIENDLY:
		return

	var before_mana := int(state.resource.mana)
	var before_max_mana := int(state.resource.max_mana)

	# Current policy:
	# refill current mana to max at start of friendly group turn.
	state.resource.mana = int(state.resource.max_mana)

	var after_mana := int(state.resource.mana)
	var after_max_mana := int(state.resource.max_mana)

	if writer != null:
		writer.emit_mana(
			get_player_id(),
			before_mana,
			after_mana,
			before_max_mana,
			after_max_mana,
			"group_turn_begin_refresh"
		)

func can_pay_card_cost(_source_id: int, card: CardData) -> bool:
	if state == null or state.resource == null or card == null:
		return false
	return int(state.resource.mana) >= int(card.cost)

func spend_mana_for_card(source_id: int, card: CardData) -> bool:
	if state == null or state.resource == null or card == null:
		return false

	var cost := int(card.get_total_cost())
	if cost <= 0:
		return true

	if int(state.resource.mana) < cost:
		return false

	var before_mana := int(state.resource.mana)
	var before_max_mana := int(state.resource.max_mana)

	state.resource.mana -= cost

	var after_mana := int(state.resource.mana)
	var after_max_mana := int(state.resource.max_mana)

	if writer != null:
		card.ensure_uid()
		writer.emit_mana(
			int(source_id),
			before_mana,
			after_mana,
			before_max_mana,
			after_max_mana,
			"card_spend",
			{
				Keys.CARD_UID: String(card.uid),
				Keys.CARD_NAME: String(card.name),
				Keys.AMOUNT: int(cost),
			}
		)

	return true

# ============================================================================
# AI planning helpers
# ============================================================================

func plan_intent(cid: int, allow_hooks := true, clear_dirty := true) -> void:
	if state == null:
		return

	var u: CombatantState = state.get_unit(int(cid))
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	ActionPlanner.ensure_ai_state_initialized(u)
	u.ai_state[ActionPlanner.FIRST_INTENTS_READY] = true

	if bool(u.ai_state.get(&"planning_now", false)) or bool(u.ai_state.get(ActionPlanner.IS_ACTING, false)):
		u.ai_state[&"replan_dirty"] = true
		return

	u.ai_state[&"planning_now"] = true

	var ctx_ai := _make_ai_ctx(u)
	ActionPlanner.ensure_valid_plan_sim(u.combatant_data.ai, ctx_ai, allow_hooks)

	u.ai_state[&"planning_now"] = false
	if clear_dirty:
		u.ai_state[&"replan_dirty"] = false


func plan_intents() -> void:
	if state == null:
		return

	for cid in state.units.keys():
		plan_intent(int(cid))


func _make_ai_ctx(u: CombatantState) -> NPCAIContext:
	var ctx := NPCAIContext.new()
	ctx.api = self
	ctx.cid = int(u.id)
	ctx.combatant_state = u
	ctx.combatant_data = u.combatant_data
	ctx.state = u.ai_state
	ctx.rng = u.rng
	ctx.params = {}
	ctx.forecast = false
	return ctx


# ============================================================================
# Damage / reaction hooks
# ============================================================================

func modify_damage_amount(ctx: DamageContext, base: int) -> int:
	var amount := int(base)
	if state == null or ctx == null:
		return amount

	var src := state.get_unit(int(ctx.source_id))
	var tgt := state.get_unit(int(ctx.target_id))

	if src != null and src.modifiers:
		amount = src.modifiers.apply(ctx.deal_modifier_type, amount)

	if tgt != null and tgt.modifiers:
		amount = tgt.modifiers.apply(ctx.take_modifier_type, amount)

	return amount


func on_damage_applied(ctx: DamageContext) -> void:
	if state == null or ctx == null:
		return

	var tid := int(ctx.target_id)
	var u: CombatantState = state.get_unit(tid)
	if u == null:
		return

	SimStatusSystem.on_damage_taken(self, ctx)

	if !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	if u.ai_state == null:
		u.ai_state = {}

	u.ai_state[ActionPlanner.DMG_SINCE_LAST_TURN] = int(
		u.ai_state.get(ActionPlanner.DMG_SINCE_LAST_TURN, 0)
	) + int(ctx.health_damage)

	_request_replan(tid)


# ============================================================================
# Internal mutation helpers
# ============================================================================

func _make_unit_from_combatant_data(
	combatant_data: CombatantData,
	id: int,
	group_index: int,
	is_player: bool
) -> CombatantState:
	var u := CombatantState.new()
	u.id = int(id)
	u.rng = RNG.new(RNGUtil.mix_seed(state.battle_seed, u.id))
	u.combatant_data = combatant_data
	u.init_from_combatant_data(combatant_data)

	u.type = (
		CombatantView.Type.PLAYER
		if is_player
		else CombatantView.Type.ALLY if group_index == FRIENDLY
		else CombatantView.Type.ENEMY
	)

	u.mortality = CombatantView.Mortality.MORTAL

	if combatant_data.resource_path != "":
		u.data_proto_path = String(combatant_data.resource_path)

	return u


func _make_spawn_spec_from_data(combatant_data: CombatantData, u: CombatantState) -> Dictionary:
	return {
		Keys.COMBATANT_NAME: String(combatant_data.name),
		Keys.MAX_HEALTH: int(combatant_data.max_health),
		Keys.HEALTH: int(combatant_data.health),
		Keys.MAX_MANA: int(combatant_data.max_mana),
		Keys.APM: int(combatant_data.apm),
		Keys.APR: int(combatant_data.apr),
		Keys.PROTO_PATH: String(combatant_data.resource_path),
		Keys.ART_UID: String(combatant_data.character_art_uid),
		Keys.ART_FACES_RIGHT: bool(combatant_data.facing_right),
		Keys.HEIGHT: int(combatant_data.height),
		Keys.COLOR_TINT: combatant_data.color_tint as Color,
		Keys.MORTALITY: int(u.mortality),
	}


func _maybe_release_soulbound_reserve(u: CombatantState, reason: String) -> void:
	if u == null:
		return
	if int(u.mortality) != int(CombatantView.Mortality.SOULBOUND):
		return

	var uid := String(u.bound_card_uid) if ("bound_card_uid" in u) else ""
	if uid == "":
		return

	if writer != null:
		writer.emit_summon_reserve_released(int(u.id), uid, String(reason))

	u.bound_card_uid = ""


func _move_id_to_index(group_index: int, id: int, new_index: int) -> void:
	var g := state.groups[int(group_index)]
	var old := g.index_of(int(id))
	if old == -1:
		return

	g.remove(int(id))
	new_index = clampi(int(new_index), 0, g.order.size())
	g.add(int(id), int(new_index))


func _swap_ids(group_index: int, a: int, b: int) -> void:
	var g := state.groups[int(group_index)]
	var ai := g.index_of(int(a))
	var bi := g.index_of(int(b))
	if ai == -1 or bi == -1 or ai == bi:
		return

	var tmp := g.order[ai]
	g.order[ai] = g.order[bi]
	g.order[bi] = tmp


func _rebuild_modifier_cache_for(_id: int) -> void:
	# Placeholder:
	# translate StatusState -> ModifierCache here later
	pass


# ============================================================================
# Other API surface / stubs
# ============================================================================

func apply_attack_now(spec: SimAttackSpec) -> bool:
	if spec == null or state == null:
		return false
	if int(spec.attacker_id) <= 0 or !is_alive(int(spec.attacker_id)):
		return false

	var ai_ctx := NPCAIContext.new()
	ai_ctx.api = self
	ai_ctx.cid = int(spec.attacker_id)
	ai_ctx.combatant_state = state.get_unit(int(spec.attacker_id))
	ai_ctx.state = {}
	ai_ctx.params = {}
	ai_ctx.forecast = false

	if spec.param_models:
		for m in spec.param_models:
			if m != null:
				m.change_params_sim(ai_ctx)

	return resolve_attack(ai_ctx)


func run_status_proc(_target_id: int, _proc_type: Status.ProcType) -> void:
	pass


func resolve_heal(_ctx: HealContext) -> void:
	pass


func resolve_attack_now(_ctx: AttackNowContext) -> void:
	pass


func apply_damage_amount(_ctx: DamageContext, _amount: int) -> void:
	pass


func play_sfx(sound: Sound) -> void:
	if sound:
		SFXPlayer.play(sound)
