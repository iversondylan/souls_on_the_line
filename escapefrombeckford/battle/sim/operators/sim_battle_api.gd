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
var runtime: SimRuntime
var is_main: bool = true

# Runtime signals
signal summoned(ctx: SummonContext)
signal unit_removed(id: int, g: int, reason: String)
signal urgent_planning_requested()

var scopes: BattleScopeManager
var writer: BattleEventWriter


# ============================================================================
# Init
# ============================================================================

func _init(_state: BattleState) -> void:
	state = _state


# ============================================================================
# Combatant Queries
# ============================================================================

func is_alive(combat_id: int) -> bool:
	return state != null and state.is_alive(int(combat_id))


func get_group(combat_id: int) -> int:
	if state == null:
		return -1
	var u := state.get_unit(int(combat_id))
	return int(u.team) if u != null else -1


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


func get_rearmost_combatant_id(group_index: int) -> int:
	var ids := get_combatants_in_group(group_index, false)
	return int(ids[-1]) if ids.size() > 0 else 0


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


func get_summon_card_max_health_bonus(card_uid: String) -> int:
	if state == null:
		return 0
	var uid := String(card_uid)
	if uid.is_empty():
		return 0
	return int(state.summon_card_max_health_bonus.get(uid, 0))


func add_summon_card_max_health_bonus(card_uid: String, amount: int) -> int:
	if state == null:
		return 0
	var uid := String(card_uid)
	if uid.is_empty():
		return 0
	if int(amount) == 0:
		return get_summon_card_max_health_bonus(uid)
	var next_amount := maxi(0, get_summon_card_max_health_bonus(uid) + int(amount))
	if next_amount <= 0:
		state.summon_card_max_health_bonus.erase(uid)
		return 0
	state.summon_card_max_health_bonus[uid] = next_amount
	return next_amount


func emit_modify_battle_card(card_uid: String, modified_fields: Dictionary, reason: String = "") -> void:
	if writer == null:
		return
	var uid := String(card_uid)
	if uid.is_empty():
		return
	if modified_fields == null or modified_fields.is_empty():
		return
	writer.emit_modify_battle_card(uid, modified_fields, reason)


func emit_draw_cards(ctx: DrawContext) -> void:
	if writer == null or ctx == null:
		return
	if int(ctx.amount) <= 0:
		return
	writer.emit_draw_cards(
		int(ctx.source_id),
		int(ctx.amount),
		String(ctx.reason),
		bool(ctx.disable_until_next_player_turn)
	)

func get_soulbound_ids_for_owner(_owner_id: int) -> Array[int]:
	return get_combatants_in_group_by_mortality(
		FRIENDLY,
		CombatantState.Mortality.SOULBOUND,
		false
	)


func get_combatants_in_group_by_mortality(
	group_index: int,
	mortality: CombatantState.Mortality,
	allow_dead := false
) -> Array[int]:
	var out: Array[int] = []
	if state == null:
		return out

	var gi := clampi(int(group_index), 0, 1)
	for id in state.groups[gi].order:
		var u: CombatantState = state.get_unit(int(id))
		if u == null:
			continue
		if !allow_dead and !u.is_alive():
			continue
		if int(u.mortality) == int(mortality):
			out.append(int(id))
	return out


func count_mortality_in_group(group_index: int, mortality: CombatantState.Mortality) -> int:
	return get_combatants_in_group_by_mortality(group_index, mortality, false).size()

func has_status(combat_id: int, status_id: StringName) -> bool:
	if state == null:
		return false
	
	var u := state.get_unit(int(combat_id))
	if u == null or !u.is_alive():
		return false
	
	return u.statuses.has(status_id, false)


func get_status_intensity(combat_id: int, status_id: StringName) -> int:
	if state == null:
		return -1

	var u := state.get_unit(int(combat_id))
	if u == null or !u.is_alive() or u.statuses == null:
		return -1

	var stack: StatusStack = u.statuses.get_status_stack(status_id, false)
	if stack == null:
		return -1

	return int(stack.intensity)


# ============================================================================
# Derived Query Methods (API-owned)
# ============================================================================

func get_effective_status_contexts_for_unit(
	target_id: int,
	include_pending_sources := {},
	allow_dead_self_aura_source := false
) -> Array[SimStatusContext]:
	return SimStatusSystem.get_effective_status_contexts_for_unit(
		self,
		target_id,
		include_pending_sources,
		allow_dead_self_aura_source
	)


func get_modifier_tokens_for_target(target_id: int, mod_type: Modifier.Type) -> Array[ModifierToken]:
	return SimArcanaSystem.get_modifier_tokens_for_target(self, target_id, mod_type)


func get_modifier_tokens_for_cid(
	target_id: int,
	mod_type: Modifier.Type,
	include_pending_sources := {}
) -> Array[ModifierToken]:
	var tokens: Array[ModifierToken] = []

	# Battle-level globals (arcana, relic-like systems, etc.)
	tokens.append_array(get_modifier_tokens_for_target(target_id, mod_type))

	var target: CombatantState = state.get_unit(target_id) if state != null else null
	if target == null or !target.is_alive():
		return tokens

	tokens.append_array(_get_effective_status_modifier_tokens_for_target(target_id, mod_type, include_pending_sources))
	return tokens


func _get_effective_status_modifier_tokens_for_target(
	target_id: int,
	mod_type: Modifier.Type,
	include_pending_sources := {}
) -> Array[ModifierToken]:
	var out: Array[ModifierToken] = []
	if state == null or state.status_catalog == null:
		return out

	for ctx: SimStatusContext in get_effective_status_contexts_for_unit(target_id, include_pending_sources):
		if ctx == null or !ctx.is_valid():
			continue
		var proto := ctx.proto
		if proto == null:
			continue
		if !proto.contributes_modifier():
			continue
		if mod_type not in proto.get_contributed_modifier_types():
			continue

		var tokens := proto.get_modifier_tokens(ctx.make_token_ctx())
		for token in tokens:
			if _modifier_token_applies_to_target(token, target_id):
				out.append(token)

	return out


static func _modifier_token_applies_to_target(token: ModifierToken, target_id: int) -> bool:
	if token == null:
		return false

	match int(token.scope):
		ModifierToken.ModScope.GLOBAL:
			return true
		ModifierToken.ModScope.SELF:
			return int(token.owner_id) == int(target_id)
		ModifierToken.ModScope.TARGET:
			return int(token.owner_id) == int(target_id)
		_:
			return false


# ============================================================================
# Targeting Queries
# ============================================================================

func get_targets_for_attack_sequence(ai_ctx) -> Array:
	if ai_ctx == null:
		return []

	var attacker_id: int = ai_ctx.get_actor_id() if ai_ctx is NPCAIContext else 0
	if attacker_id <= 0:
		return []

	var targeting_ctx := TargetingContext.new()
	targeting_ctx.api = self
	targeting_ctx.source_id = attacker_id
	targeting_ctx.params = ai_ctx.params if ai_ctx.params != null else {}
	targeting_ctx.target_type = int(targeting_ctx.params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))
	targeting_ctx.attack_mode = int(targeting_ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))

	return AttackTargeting.get_target_ids(targeting_ctx)

# ============================================================================
# Resource Queries
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

func get_pending_discard() -> DiscardRequest:
	if state == null or state.resource == null:
		return null
	return state.resource.pending_discard

# ============================================================================
# Planning / Dirty Requests
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
	u.ai_state[Keys.REPLAN_DIRTY] = true

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
	u.ai_state[Keys.INTENT_DIRTY] = true


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
		#print("sim_battle_api.gd _request_immediate_planning_flush_if_needed() affects_legality: false, status: ", proto.get_id())
		return
	#print("sim_battle_api.gd _request_immediate_planning_flush_if_needed() affects_legality: true, status: ", proto.get_id())
	# Dirtiness should already be requested before this point,
	# but make sure the target definitely gets both.
	_request_replan(int(target_id))
	_request_intent_refresh(int(target_id))
	
	urgent_planning_requested.emit()

func _request_turn_order_rebuild() -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_turn_order_rebuild()

func _request_outcome_check() -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_outcome_check()

func _on_status_changed(cid: int) -> void:
	_request_replan(int(cid))

func _track_status_aura_projection(source_owner_id: int, status_id: StringName, pending := false) -> void:
	ProjectionChangeSystem.track_status_aura(self, source_owner_id, status_id, pending)

func _untrack_status_aura_projection(source_owner_id: int, status_id: StringName, pending := false) -> void:
	ProjectionChangeSystem.untrack_status_aura(self, source_owner_id, status_id, pending)

func _untrack_auras_for_removed_combatant(removed_id: int) -> void:
	ProjectionChangeSystem.untrack_auras_from_removed_combatant(self, removed_id)

func _swap_status_aura_projection_lane(
	source_owner_id: int,
	status_id: StringName,
	from_pending: bool,
	to_pending: bool
) -> void:
	ProjectionChangeSystem.swap_status_aura_lane(
		self,
		source_owner_id,
		status_id,
		from_pending,
		to_pending
	)

func _refresh_status_aura_projection(source_owner_id: int, status_id: StringName, pending := false) -> void:
	ProjectionChangeSystem.refresh_status_aura(self, source_owner_id, status_id, pending)



# ============================================================================
# Atomic Combat Mutations
# ============================================================================

func resolve_damage_immediate(ctx: DamageContext) -> int:
	if ctx == null or state == null:
		return 0
	
	if !state.is_alive(int(ctx.target_id)):
		ctx.amount = 0
		ctx.display_amount = 0
		ctx.banish_amount = 0
		ctx.applied_banish_amount = 0
		return 0
	
	ctx.phase = DamageContext.Phase.PRE_MODIFIERS
	var policy := int(ctx.modifier_policy)
	var apply_deal_modifiers := (policy & int(DamageContext.ModifierPolicy.SKIP_DEAL_MODIFIERS)) == 0
	var apply_take_modifiers := (policy & int(DamageContext.ModifierPolicy.SKIP_TAKE_MODIFIERS)) == 0

	var normal_amount := int(ctx.base_amount)
	if apply_deal_modifiers and int(ctx.deal_modifier_type) != int(Modifier.Type.NO_MODIFIER):
		normal_amount = SimModifierResolver.get_modified_value(
			state,
			int(normal_amount),
			ctx.deal_modifier_type,
			int(ctx.source_id)
		)
	if apply_take_modifiers and int(ctx.take_modifier_type) != int(Modifier.Type.NO_MODIFIER):
		normal_amount = SimModifierResolver.get_modified_value(
			state,
			int(normal_amount),
			ctx.take_modifier_type,
			int(ctx.target_id)
		)

	var banish_amount := int(ctx.base_banish_amount)
	if apply_deal_modifiers:
		banish_amount = SimModifierResolver.get_modified_value(
			state,
			int(banish_amount),
			Modifier.Type.BANISH_DMG_DEALT,
			int(ctx.source_id)
		)
	normal_amount = maxi(int(normal_amount), 0)
	banish_amount = maxi(int(banish_amount), 0)
	ctx.banish_amount = banish_amount
	ctx.applied_banish_amount = 0
	ctx.display_amount = normal_amount + banish_amount
	ctx.amount = normal_amount
	ctx.phase = DamageContext.Phase.POST_MODIFIERS

	var tgt: CombatantState = state.get_unit(int(ctx.target_id))
	if tgt == null:
		ctx.amount = 0
		ctx.display_amount = 0
		ctx.banish_amount = 0
		ctx.applied_banish_amount = 0
		return 0

	if tgt.mortality == CombatantState.Mortality.SOULBOUND or tgt.mortality == CombatantState.Mortality.DEPLETE:
		ctx.applied_banish_amount = banish_amount
		ctx.amount += banish_amount

	ctx.phase = DamageContext.Phase.PRE_APPLICATION
	SimStatusSystem.on_damage_will_be_taken(self, ctx)
	SimArcanaSystem.on_damage_will_be_taken(self, ctx)
	ctx.amount = maxi(int(ctx.amount), 0)
	var original_applied_banish := maxi(int(ctx.applied_banish_amount), 0)
	var post_hook_banish := mini(original_applied_banish, maxi(int(ctx.amount) - normal_amount, 0))
	var post_hook_normal := maxi(int(ctx.amount) - post_hook_banish, 0)
	ctx.applied_banish_amount = post_hook_banish

	var remaining_normal := post_hook_normal
	var remaining_banish := post_hook_banish
	var before_health := int(tgt.health)

	var armor_damage := 0
	var health_damage := 0

	var armor_absorb_normal := mini(remaining_normal, maxi(int(tgt.armor), 0))
	tgt.armor = int(tgt.armor) - armor_absorb_normal
	remaining_normal -= armor_absorb_normal
	armor_damage += armor_absorb_normal

	var health_absorb_normal := mini(remaining_normal, maxi(int(tgt.health), 0))
	tgt.health = int(tgt.health) - health_absorb_normal
	remaining_normal -= health_absorb_normal
	health_damage += health_absorb_normal

	var armor_absorb_banish := mini(remaining_banish, maxi(int(tgt.armor), 0))
	tgt.armor = int(tgt.armor) - armor_absorb_banish
	remaining_banish -= armor_absorb_banish
	armor_damage += armor_absorb_banish

	var health_absorb_banish := mini(remaining_banish, maxi(int(tgt.health), 0))
	tgt.health = int(tgt.health) - health_absorb_banish
	remaining_banish -= health_absorb_banish
	health_damage += health_absorb_banish

	ctx.armor_damage = armor_damage
	ctx.health_damage = health_damage
	ctx.overflow_amount = maxi(int(remaining_normal) + int(remaining_banish), 0)
	ctx.overflow_banish_amount = maxi(int(remaining_banish), 0)
	ctx.was_lethal = (int(tgt.health) <= 0)
	ctx.before_health = before_health
	ctx.after_health = int(tgt.health)
	ctx.phase = DamageContext.Phase.APPLIED
	
	if writer != null:
		writer.emit_damage_applied(
			int(ctx.source_id),
			int(ctx.target_id),
			int(ctx.base_amount),
			int(ctx.base_banish_amount),
			int(ctx.amount),
			int(ctx.display_amount),
			int(ctx.banish_amount),
			int(ctx.applied_banish_amount),
			int(ctx.armor_damage),
			int(ctx.health_damage),
			bool(ctx.was_lethal),
			int(ctx.before_health),
			int(ctx.after_health),
			ctx.event_extra if ctx.event_extra != null else {},
		)
	
	on_damage_applied(ctx)
	
	if bool(ctx.was_lethal):
		var death_ctx := DeathContext.new()
		death_ctx.dead_id = int(ctx.target_id)
		death_ctx.killer_id = int(ctx.source_id)
		death_ctx.reason = "damage"
		death_ctx.origin_card_uid = String(ctx.origin_card_uid)
		death_ctx.origin_arcanum_id = ctx.origin_arcanum_id
		death_ctx.event_extra = ctx.event_extra.duplicate() if ctx.event_extra != null else {}
		resolve_death(death_ctx)
	
	return int(ctx.amount)

func change_max_health(
	cid: int,
	amount: int,
	change_health_relative := false,
	reason: String = ""
) -> void:
	if state == null:
		return
	if int(cid) <= 0:
		return
	if int(amount) == 0:
		return

	var u: CombatantState = state.get_unit(int(cid))
	if u == null or !u.alive:
		return

	var before_max_health := int(u.max_health)
	var before_health := int(u.health)

	var after_max_health := maxi(0, before_max_health + int(amount))
	if after_max_health == before_max_health:
		return

	u.max_health = after_max_health

	if bool(change_health_relative):
		u.health = before_health + int(amount)
	else:
		u.health = mini(before_health, after_max_health)

	u.health = clampi(int(u.health), 0, int(u.max_health))

	var after_health := int(u.health)

	if writer != null:
		writer.emit_change_max_health(
			0,
			int(cid),
			before_max_health,
			after_max_health,
			before_health,
			after_health,
			int(amount),
			bool(change_health_relative),
			reason
		)

	# If this can affect planning / legality later, leave yourself this hook point.
	# _request_replan(int(cid))
	# _request_intent_refresh(int(cid))

	if before_health > 0 and after_health <= 0:
		var death_ctx := DeathContext.new()
		death_ctx.dead_id = int(cid)
		death_ctx.reason = "change_max_health:" + String(reason)
		resolve_death(death_ctx)

func resolve_death(ctx: DeathContext) -> void:
	if state == null or ctx == null:
		return
	if int(ctx.dead_id) <= 0:
		return
	
	var u: CombatantState = state.get_unit(int(ctx.dead_id))
	if u == null or !u.alive:
		return
	
	_maybe_release_soulbound_reserve(u, "fade:" + String(ctx.reason))

	var g := int(u.team)
	ctx.group_index = g
	ctx.before_order_ids = PackedInt32Array(state.groups[g].order) if g != -1 else PackedInt32Array()
	var insert_index := ctx.before_order_ids.find(int(ctx.dead_id))

	u.alive = false
	if g != -1:
		state.groups[g].remove(int(ctx.dead_id))

	_untrack_auras_for_removed_combatant(int(ctx.dead_id))

	ctx.after_order_ids = PackedInt32Array(state.groups[g].order) if g != -1 else PackedInt32Array()
	
	unit_removed.emit(int(ctx.dead_id), int(g), "death:" + String(ctx.reason))

	if writer != null:
		writer.emit_died(
			int(ctx.killer_id),
			int(ctx.dead_id),
			g,
			ctx.before_order_ids,
			ctx.after_order_ids,
			String(ctx.reason),
			ctx.event_extra if ctx.event_extra != null else {}
		)

	ctx.died = true
	_request_outcome_check()

	if runtime != null:
		var reaction := OnDeathDelayedReaction.new()
		reaction.dead_id = int(ctx.dead_id)
		reaction.killer_id = int(ctx.killer_id)
		reaction.group_index = int(ctx.group_index)
		reaction.insert_index = int(insert_index)
		reaction.reason = String(ctx.reason)
		reaction.before_order_ids = PackedInt32Array(ctx.before_order_ids)
		reaction.after_order_ids = PackedInt32Array(ctx.after_order_ids)
		reaction.source_reason = String(ctx.reason)
		reaction.origin_card_uid = String(ctx.origin_card_uid)
		reaction.origin_arcanum_id = ctx.origin_arcanum_id
		runtime.enqueue_delayed_reaction(reaction)
		if !runtime.is_in_strike_resolution():
			runtime.drain_delayed_reactions(DelayedReaction.Timing.AFTER_STRIKE)
	else:
		SimStatusSystem.on_death(self, int(ctx.dead_id), int(ctx.killer_id), String(ctx.reason))
		SimArcanaSystem.on_death(self, int(ctx.dead_id), int(ctx.killer_id), String(ctx.reason))


func fade_unit(ctx: FadeContext) -> void:
	if state == null or ctx == null:
		return
	
	var u: CombatantState = state.get_unit(int(ctx.actor_id))
	if u == null or !u.alive:
		return
	
	_maybe_release_soulbound_reserve(u, "fade:" + String(ctx.reason))
	
	var g := int(u.team)
	ctx.group_index = g
	ctx.before_order_ids = PackedInt32Array(state.groups[g].order)
	
	u.alive = false
	if g != -1:
		state.groups[g].remove(int(ctx.actor_id))

	_untrack_auras_for_removed_combatant(int(ctx.actor_id))

	unit_removed.emit(int(ctx.actor_id), int(g), "fade:" + String(ctx.reason))
	
	ctx.after_order_ids = PackedInt32Array(state.groups[g].order) if g != -1 else PackedInt32Array()
	
	_request_turn_order_rebuild()
	_request_outcome_check()
	
	if writer != null:
		writer.emit_faded(int(ctx.actor_id), int(g), ctx.before_order_ids, ctx.after_order_ids, String(ctx.reason))

	ctx.faded = true


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

	var proto := SimStatusSystem.get_proto(self, ctx.status_id)
	
	if int(ctx.intensity) == 0:
		ctx.intensity = 1
	
	var changed := u.statuses.add_or_reapply_ctx(
		ctx,
		int(proto.get_max_intensity()) if proto != null else 0
	)
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
				Keys.STATUS_PENDING: bool(ctx.pending),
				Keys.REASON: String(ctx.reason),
				Keys.TARGET_IDS: PackedInt32Array([int(ctx.target_id)]),
				Keys.STATUS_PRESENTATION_HINT: ctx.presentation_hint,
				Keys.DELTA_INTENSITY: int(ctx.delta_intensity),
				Keys.DELTA_DURATION: int(ctx.delta_duration),
				Keys.BEFORE_PENDING: bool(ctx.before_pending),
				Keys.AFTER_PENDING: bool(ctx.after_pending),
				Keys.BEFORE_INTENSITY: int(ctx.before_intensity),
				Keys.BEFORE_DURATION: int(ctx.before_duration),
				Keys.AFTER_INTENSITY: int(ctx.after_intensity),
				Keys.AFTER_DURATION: int(ctx.after_duration),
			}
		)
	
	_rebuild_modifier_cache_for(int(ctx.target_id))

	if SimStatusSystem.is_aura_proto(proto):
		_track_status_aura_projection(int(ctx.target_id), ctx.status_id, bool(ctx.pending))
	
	if !bool(ctx.pending):
		var status_ctx := SimStatusSystem.make_context(
			self,
			int(ctx.target_id),
			u.statuses.get_status_stack(ctx.status_id, false)
		)
		if status_ctx != null and status_ctx.proto != null:
			status_ctx.proto.on_apply(status_ctx, ctx)
	
	if !SimStatusSystem.is_aura_proto(proto):
		_request_intent_refresh(int(ctx.target_id))
	
	if !bool(ctx.pending) and !SimStatusSystem.is_aura_proto(proto):
		_on_status_changed(int(ctx.target_id))
		_request_immediate_planning_flush_if_needed(int(ctx.target_id), proto)

func realize_pending_statuses(target_id: int, source_id: int = 0, reason: String = "") -> void:
	SimStatusSystem.realize_pending_statuses(self, target_id, source_id, reason)


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
	
	var old_stack: StatusStack = u.statuses.get_status_stack(ctx.status_id, bool(ctx.pending))
	if old_stack == null:
		return
	
	var proto := SimStatusSystem.get_proto(self, ctx.status_id)
	
	var before_i := int(old_stack.intensity)
	var before_d := int(old_stack.duration)
	
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
				Keys.STATUS_PENDING: bool(ctx.pending),
				Keys.BEFORE_PENDING: bool(ctx.before_pending),
				Keys.AFTER_PENDING: bool(ctx.after_pending),
				Keys.BEFORE_INTENSITY: before_i,
				Keys.BEFORE_DURATION: before_d,
				Keys.AFTER_INTENSITY: 0,
				Keys.AFTER_DURATION: 0,
				Keys.DELTA_INTENSITY: -before_i,
				Keys.DELTA_DURATION: -before_d,
			}
		)
	
	_rebuild_modifier_cache_for(int(ctx.target_id))

	if SimStatusSystem.is_aura_proto(proto):
		_untrack_status_aura_projection(int(ctx.target_id), ctx.status_id, bool(ctx.pending))
	
	if !bool(ctx.pending) and status_ctx != null and status_ctx.proto != null:
		status_ctx.proto.on_remove(status_ctx, ctx)
	
	if !SimStatusSystem.is_aura_proto(proto):
		_request_intent_refresh(int(ctx.target_id))
	
	if !bool(ctx.pending) and !SimStatusSystem.is_aura_proto(proto):
		_on_status_changed(int(ctx.target_id))
		_request_immediate_planning_flush_if_needed(int(ctx.target_id), proto)

# ============================================================================
# Spawn / summon
# ============================================================================

func spawn_from_data(
	combatant_data: CombatantData,
	group_index: int,
	insert_index: int = -1,
	is_player := false,
	current_health_override := -1
) -> int:
	if combatant_data == null or state == null:
		return 0
	
	var g := clampi(int(group_index), 0, 1)
	var id := state.alloc_id()
	
	if is_player:
		state.groups[FRIENDLY].player_id = id
	
	var u := _make_unit_from_combatant_data(combatant_data, id, g, is_player, int(current_health_override))
	state.add_unit(u, g, int(insert_index))
	_rebuild_modifier_cache_for(id)
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
	var source_id := int(ctx.source_id)
	
	var windup_order := ctx.windup_order_ids
	if windup_order == null or windup_order.is_empty():
		windup_order = PackedInt32Array(state.groups[g].order)
	ctx.before_order_ids = windup_order
	
	var id := state.alloc_id()
	var u := _make_unit_from_combatant_data(ctx.summon_data, id, g, false)
	u.bound_card_uid = String(ctx.bound_card_uid)
	var summon_bonus := get_summon_card_max_health_bonus(u.bound_card_uid)
	if summon_bonus > 0:
		u.max_health += summon_bonus
		u.health += summon_bonus
	u.mortality = int(ctx.mortality) as CombatantState.Mortality
	u.type = CombatantView.Type.ALLY if g == 0 else CombatantView.Type.ENEMY
	
	state.add_unit(u, g, int(ctx.insert_index))
	_rebuild_modifier_cache_for(id)
	_request_turn_order_rebuild()
	
	if writer != null:
		var spec := _make_spawn_spec_from_data(ctx.summon_data, u)
		var after_order_ids := PackedInt32Array(state.groups[g].order)
		ctx.after_order_ids = after_order_ids
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
	if ctx.after_order_ids.is_empty():
		ctx.after_order_ids = PackedInt32Array(state.groups[g].order)

	_enforce_player_group_mortality_cap(int(id), int(g))
	
	summoned.emit(ctx)
	
	_request_replan(int(id))
	_request_intent_refresh(int(id))
	
	if checkpoint_processor != null:
		checkpoint_processor.request_followup_flush()


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
	return count_mortality_in_group(group_index, CombatantState.Mortality.SOULBOUND)


# ============================================================================
# Pending Input / Discard
# ============================================================================

func request_player_discard(req: DiscardRequest) -> bool:
	if req == null or state == null or state.resource == null:
		return false
	
	if state.resource.pending_discard != null:
		push_warning("SimBattleAPI.request_player_discard(): discard already pending")
		return false
	
	state.resource.pending_discard = req
	
	if writer != null:
		writer.emit_discard_requested(req)

	return true


func resolve_player_discard(selected_card_uids: Array[String]) -> void:
	if state == null or state.resource == null or state.resource.pending_discard == null:
		push_warning("SimBattleAPI.resolve_player_discard(): no pending discard")
		return
	
	var req := state.resource.pending_discard
	state.resource.pending_discard = null
	
	if writer != null:
		writer.emit_discard_resolved(req, selected_card_uids)

# ============================================================================
# Resource Mutations
# ============================================================================

func set_mana(ctx: ManaContext, extra: Dictionary = {}) -> void:
	if state == null or state.resource == null or ctx == null:
		return
	
	ctx.before_mana = int(state.resource.mana)
	ctx.before_max_mana = int(state.resource.max_mana)
	
	state.resource.mana = clampi(int(ctx.new_mana), 0, int(state.resource.max_mana))
	
	ctx.after_mana = int(state.resource.mana)
	ctx.after_max_mana = int(state.resource.max_mana)
	ctx.changed = (
		ctx.before_mana != ctx.after_mana
		or ctx.before_max_mana != ctx.after_max_mana
	)
	
	if writer != null and ctx.changed:
		writer.emit_mana(
			int(ctx.source_id),
			ctx.before_mana,
			ctx.after_mana,
			ctx.before_max_mana,
			ctx.after_max_mana,
			ctx.reason,
			extra
		)


func set_max_mana(ctx: ManaContext) -> void:
	if state == null or state.resource == null or ctx == null:
		return
	
	ctx.before_mana = int(state.resource.mana)
	ctx.before_max_mana = int(state.resource.max_mana)
	
	state.resource.max_mana = maxi(int(ctx.new_max_mana), 0)
	if ctx.refill:
		state.resource.mana = int(state.resource.max_mana)
	else:
		state.resource.mana = mini(int(state.resource.mana), int(state.resource.max_mana))
	
	ctx.after_mana = int(state.resource.mana)
	ctx.after_max_mana = int(state.resource.max_mana)
	ctx.changed = (
		ctx.before_mana != ctx.after_mana
		or ctx.before_max_mana != ctx.after_max_mana
	)
	
	if writer != null and ctx.changed:
		writer.emit_mana(
			int(ctx.source_id),
			ctx.before_mana,
			ctx.after_mana,
			ctx.before_max_mana,
			ctx.after_max_mana,
			ctx.reason
		)


func gain_mana(ctx: ManaContext) -> void:
	if state == null or state.resource == null or ctx == null:
		return
	if int(ctx.amount) == 0:
		return
	ctx.new_mana = int(state.resource.mana) + int(ctx.amount)
	set_mana(ctx)

func can_pay_card_cost(_source_id: int, card: CardData) -> bool:
	if state == null or state.resource == null or card == null:
		return false
	return int(state.resource.mana) >= int(card.get_total_cost())

func spend_mana_for_card(ctx: ManaContext, card: CardData) -> bool:
	if state == null or state.resource == null or card == null or ctx == null:
		return false
	
	var cost := int(card.get_total_cost())
	if cost <= 0:
		ctx.new_mana = int(state.resource.mana)
		set_mana(ctx)
		return true
	
	if int(state.resource.mana) < cost:
		return false
	
	ctx.amount = cost
	ctx.mode = ManaContext.Mode.SPEND_FOR_CARD
	ctx.new_mana = int(state.resource.mana) - cost
	card.ensure_uid()
	ctx.card_uid = String(card.uid)
	ctx.card_name = String(card.name)
	
	set_mana(ctx, {
		Keys.CARD_UID: ctx.card_uid,
		Keys.CARD_NAME: ctx.card_name,
		Keys.AMOUNT: int(cost),
	})
	
	return true

# ============================================================================
# Planning Helpers
# ============================================================================

func plan_intent(cid: int, allow_hooks := true, clear_dirty := true) -> void:
	if state == null or state.has_terminal_outcome():
		return

	var u: CombatantState = state.get_unit(int(cid))
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	ActionPlanner.ensure_ai_state_initialized(u)
	u.ai_state[Keys.FIRST_INTENTS_READY] = true

	if bool(u.ai_state.get(Keys.PLANNING_NOW, false)) or bool(u.ai_state.get(Keys.IS_ACTING, false)):
		u.ai_state[Keys.REPLAN_DIRTY] = true
		return

	u.ai_state[Keys.PLANNING_NOW] = true

	var ctx_ai := ActionPlanner.make_context(self, u)
	ActionPlanner.ensure_valid_plan_sim(u.combatant_data.ai, ctx_ai, allow_hooks)

	u.ai_state[Keys.PLANNING_NOW] = false
	if clear_dirty:
		u.ai_state[Keys.REPLAN_DIRTY] = false


func plan_intents() -> void:
	if state == null:
		return
	
	for cid in state.units.keys():
		plan_intent(int(cid))

func debug_kill_all_enemies(reason: String = "debug_kill_all_enemies") -> void:
	if state == null:
		return

	var enemy_ids := get_combatants_in_group(ENEMY, false)
	if enemy_ids.is_empty():
		return

	for cid in enemy_ids:
		var enemy_id := int(cid)
		if enemy_id <= 0 or !is_alive(enemy_id):
			continue
		var death_ctx := DeathContext.new()
		death_ctx.dead_id = enemy_id
		death_ctx.reason = reason
		resolve_death(death_ctx)

	# Make sure downstream systems settle immediately the same way a card-resolution checkpoint would.
	if checkpoint_processor != null:
		checkpoint_processor.request_outcome_check()
		checkpoint_processor.request_turn_order_rebuild()
		checkpoint_processor.request_replan_all()
		checkpoint_processor.request_intent_refresh_all()



# ============================================================================
# Reaction Hooks
# ============================================================================

func modify_damage_amount(ctx: DamageContext, base: int) -> int:
	var amount := int(base)
	if state == null or ctx == null:
		return amount

	amount = SimModifierResolver.get_modified_value(
		state,
		amount,
		int(ctx.deal_modifier_type),
		int(ctx.source_id)
	)
	amount = SimModifierResolver.get_modified_value(
		state,
		amount,
		int(ctx.take_modifier_type),
		int(ctx.target_id)
	)
	return maxi(int(amount), 0)


func on_damage_applied(ctx: DamageContext) -> void:
	if state == null or ctx == null:
		return
	
	var tid := int(ctx.target_id)
	var u: CombatantState = state.get_unit(tid)
	if u == null:
		return
	
	SimStatusSystem.on_damage_taken(self, ctx)
	SimArcanaSystem.on_damage_taken(self, ctx)
	
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
# Internal Mutation Helpers
# ============================================================================

func _make_unit_from_combatant_data(
	combatant_data: CombatantData,
	id: int,
	group_index: int,
	is_player: bool,
	current_health_override: int = -1
) -> CombatantState:
	var u := CombatantState.new()
	u.id = int(id)
	u.combatant_data = combatant_data
	u.init_from_combatant_data(combatant_data, current_health_override)
	
	u.type = (
		CombatantView.Type.PLAYER
		if is_player
		else CombatantView.Type.ALLY if group_index == FRIENDLY
		else CombatantView.Type.ENEMY
	)
	
	u.mortality = CombatantState.Mortality.MORTAL
	
	if combatant_data.resource_path != "":
		u.data_proto_path = String(combatant_data.resource_path)
	
	return u


func _make_spawn_spec_from_data(combatant_data: CombatantData, u: CombatantState) -> Dictionary:
	return {
		Keys.COMBATANT_NAME: String(combatant_data.name),
		Keys.MAX_HEALTH: int(u.max_health),
		Keys.HEALTH: int(u.health),
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
	if int(u.mortality) != int(CombatantState.Mortality.SOULBOUND):
		return
	
	var uid := String(u.bound_card_uid) if ("bound_card_uid" in u) else ""
	if uid == "":
		return
	
	if writer != null:
		writer.emit_summon_reserve_released(int(u.id), uid, String(reason))
	
	u.bound_card_uid = ""


func _enforce_player_group_mortality_cap(summoned_id: int, group_index: int) -> void:
	if state == null:
		return
	if int(group_index) != int(FRIENDLY):
		return

	var summoned_combatant: CombatantState = state.get_unit(int(summoned_id))
	if summoned_combatant == null or !summoned_combatant.is_alive():
		return

	var mortality: CombatantState.Mortality = summoned_combatant.mortality
	var cap := int(CombatantState.get_mortality_cap(int(mortality)))
	if cap <= 0:
		return

	var matching_ids := get_combatants_in_group_by_mortality(int(group_index), mortality, false)
	if matching_ids.size() <= cap:
		return

	matching_ids.sort()
	var to_fade := matching_ids.size() - cap
	var fade_reason := _get_mortality_cap_fade_reason(int(mortality))
	for i in range(to_fade):
		var faded_id := int(matching_ids[i])
		if faded_id <= 0 or !is_alive(faded_id):
			continue

		var fade_ctx := FadeContext.new()
		fade_ctx.actor_id = faded_id
		fade_ctx.reason = fade_reason
		fade_unit(fade_ctx)


func _get_mortality_cap_fade_reason(mortality: int) -> String:
	match int(mortality):
		int(CombatantState.Mortality.SOULBOUND):
			return "summon_over_cap_soulbound"
		int(CombatantState.Mortality.DEPLETE):
			return "summon_over_cap_deplete"
		_:
			return "summon_over_cap"


func _move_id_to_index(group_index: int, id: int, new_index: int) -> void:
	var g := state.groups[int(group_index)]
	var old := g.index_of(int(id))
	if old == -1:
		return
	
	g.remove(int(id))
	new_index = clampi(int(new_index), 0, g.order.size())
	g.add(int(id), int(new_index))


func _swap_ids(group_index: int, a: int, b: int) -> void:
	print("sim_battle_api.gd _swap_ids() g: %s, a: %s, b: %s" % [group_index,a, b])
	var g := state.groups[int(group_index)]
	var ai := g.index_of(int(a))
	var bi := g.index_of(int(b))
	if ai == -1 or bi == -1 or ai == bi:
		return
	
	var tmp := g.order[ai]
	g.order[ai] = g.order[bi]
	g.order[bi] = tmp


func _rebuild_modifier_cache_for(id: int) -> void:
	var u: CombatantState = state.get_unit(id) if state != null else null
	if u == null:
		return
	u.modifiers.clear()
	for mod_type_variant in Modifier.Type.values():
		var mod_type := mod_type_variant as Modifier.Type
		if int(mod_type) == int(Modifier.Type.NO_MODIFIER):
			continue
		var tokens := get_modifier_tokens_for_cid(id, mod_type)
		if tokens.is_empty():
			continue
		var d := SimModifierResolver.compute_modifier_deltas(mod_type, tokens)
		var flat := int(d["flat"])
		var mult := float(d["mult"])
		if flat != 0:
			u.modifiers.set_add(int(mod_type), flat)
		if mult != 1.0:
			u.modifiers.set_mul(int(mod_type), mult)


func _rebuild_all_modifier_caches() -> void:
	if state == null:
		return
	for cid in state.units.keys():
		_rebuild_modifier_cache_for(int(cid))


# ============================================================================
# Misc
# ============================================================================

func heal(ctx: HealContext) -> int:
	if ctx == null or state == null:
		return 0

	if int(ctx.target_id) <= 0:
		return 0

	if ctx.flat_amount < 0 or ctx.of_total < 0.0 or ctx.of_missing < 0.0:
		push_warning("sim_battle_api.gd heal(): negative heal input")
		return 0

	var u := state.get_unit(int(ctx.target_id))
	if u == null:
		return 0

	var before_health := int(u.health)
	var max_health := int(u.max_health)

	if max_health <= 0:
		return 0

	ctx.phase = HealContext.Phase.PRE_MODIFIERS

	# Future hook point:
	# _apply_heal_modifiers(ctx)

	var heal_amount := int(ctx.flat_amount)

	# Match your specified math exactly:
	# first flat
	var working_health := clampi(before_health + heal_amount, 0, max_health)

	# then % of current total health after flat
	if ctx.of_total > 0.0:
		working_health = clampi(
			working_health + floori(float(max_health) * ctx.of_total),
			0,
			max_health
		)

	# then % of missing health after previous steps
	if ctx.of_missing > 0.0:
		working_health = clampi(
			working_health + floori(float(max_health - working_health) * ctx.of_missing),
			0,
			max_health
		)

	ctx.phase = HealContext.Phase.POST_MODIFIERS

	var healed_amount := maxi(0, working_health - before_health)
	if healed_amount <= 0:
		ctx.healed_amount = 0
		return 0

	u.health = working_health
	ctx.healed_amount = healed_amount
	ctx.phase = HealContext.Phase.APPLIED

	if writer != null:
		writer.emit_heal_applied(
			int(ctx.source_id),
			int(ctx.target_id),
			before_health,
			int(u.health),
			int(ctx.flat_amount),
			float(ctx.of_total),
			float(ctx.of_missing),
			int(ctx.healed_amount),
			{}
		)

	#_on_health_changed(int(ctx.target_id))
	return ctx.healed_amount


func play_sfx(sound: Sound) -> void:
	if sound:
		SFXPlayer.play(sound)
