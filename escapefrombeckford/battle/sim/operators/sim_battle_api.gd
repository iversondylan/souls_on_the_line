# sim_battle_api.gd

class_name SimBattleAPI extends RefCounted

const StatusToken := preload("res://battle/sim/containers/status_token.gd")
const Interceptor := preload("res://battle/sim/interceptors/interceptor.gd")
const OnAnyDeathInterceptor := preload("res://battle/sim/interceptors/on_any_death_interceptor.gd")
const TransformerRecord := preload("res://battle/sim/containers/transformer_record.gd")

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
# - owning persistent or derived battle state
# - turn/group lifecycle orchestration
# - intent lifecycle orchestration
# - status proto classification rules
#
# Those belong in:
# - BattleState for battle-owned state and derived caches
# - CombatantState / TurnState / GroupState for structured sub-state
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
signal unit_removed(id: int, g: int, removal_type: int, reason: String)

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

func get_summon_card_ap_bonus(card_uid: String) -> int:
	if state == null:
		return 0
	var uid := String(card_uid)
	if uid.is_empty():
		return 0
	return int(state.summon_card_ap_bonus.get(uid, 0))

func add_summon_card_ap_bonus(card_uid: String, amount: int) -> int:
	if state == null:
		return 0
	var uid := String(card_uid)
	if uid.is_empty():
		return 0
	if int(amount) == 0:
		return get_summon_card_ap_bonus(uid)
	var next_amount := maxi(0, get_summon_card_ap_bonus(uid) + int(amount))
	if next_amount <= 0:
		state.summon_card_ap_bonus.erase(uid)
		return 0
	state.summon_card_ap_bonus[uid] = next_amount
	return next_amount


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
	writer.emit_draw_cards(ctx)

func process_draw_context(ctx: DrawContext) -> void:
	if ctx == null:
		return
	SimStatusSystem.on_draw_context(self, ctx)
	SimArcanaSystem.on_draw_context(self, ctx)
	emit_draw_cards(ctx)

func emit_discard_cards(ctx: DiscardContext) -> void:
	if writer == null or ctx == null:
		return
	writer.emit_discard_cards(ctx)

func process_player_turn_end_discard(ctx: DiscardContext) -> void:
	if ctx == null:
		return
	SimStatusSystem.on_player_turn_end_discard(self, ctx)
	SimArcanaSystem.on_player_turn_end_discard(self, ctx)
	emit_discard_cards(ctx)

func get_bound_ids_for_owner(_owner_id: int) -> Array[int]:
	return get_combatants_in_group_by_mortality(
		FRIENDLY,
		CombatantState.Mortality.BOUND,
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
	
	return u.statuses.has_any(status_id)


func get_status_intensity(combat_id: int, status_id: StringName) -> int:
	if state == null:
		return -1

	var u := state.get_unit(int(combat_id))
	if u == null or !u.is_alive():
		return -1

	var total := 0
	var found := false
	for token: StatusToken in u.statuses.get_all_tokens(true):
		if token == null or StringName(token.id) != status_id:
			continue
		total += int(token.intensity)
		found = true
	if !found:
		return -1

	return total


# ============================================================================
# Derived Query Methods (API facade)
# ============================================================================

func get_effective_status_contexts_for_unit(
	target_id: int
) -> Array[SimStatusContext]:
	return SimStatusSystem.get_effective_status_contexts_for_unit(
		self,
		target_id
	)

func has_cached_effective_status_contexts_for_unit(
	target_id: int,
	unit_status_version: int
) -> bool:
	if state == null:
		return false
	return state.has_cached_effective_status_contexts_for_unit(
		target_id,
		unit_status_version
	)


func _get_cached_effective_status_contexts_for_unit(
	target_id: int,
	unit_status_version: int
) -> Array[SimStatusContext]:
	if state == null:
		return []
	return state.get_cached_effective_status_contexts_for_unit(
		target_id,
		unit_status_version
	)


func _set_cached_effective_status_contexts_for_unit(
	target_id: int,
	unit_status_version: int,
	contexts: Array[SimStatusContext]
) -> void:
	if state == null:
		return
	state.set_cached_effective_status_contexts_for_unit(
		target_id,
		unit_status_version,
		contexts
	)


func _invalidate_effective_status_context_cache() -> void:
	if state == null:
		return
	state.invalidate_effective_status_context_cache()


func _mark_interceptors_dirty(hook_kind: StringName) -> void:
	if state == null:
		return
	state.mark_interceptors_dirty(hook_kind)


func _sync_status_source_transformers(source_owner_id: int, status_id: StringName) -> void:
	if state == null:
		return
	ProjectionChangeSystem.sync_status_source(self, source_owner_id, status_id)


func _sync_all_status_source_transformers(source_owner_id: int) -> void:
	if state == null or source_owner_id <= 0:
		return
	var owner: CombatantState = state.get_unit(source_owner_id)
	if owner == null or owner.statuses == null:
		return
	for status_id in owner.statuses.get_status_ids(true):
		_sync_status_source_transformers(source_owner_id, status_id)


func _sync_arcanum_source_transformers(arcanum_id: StringName) -> void:
	if state == null or state.transformer_registry == null or arcanum_id == &"":
		return
	var owner_id := int(get_player_id())
	if owner_id <= 0:
		return
	state.transformer_registry.sync_arcanum_source_transformers(
		state,
		owner_id,
		FRIENDLY,
		arcanum_id
	)
	state.transformer_registry.mark_source_dirty(
		TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY,
		owner_id,
		arcanum_id
	)
	var source_key := TransformerRecord.make_source_key(
		TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY,
		owner_id,
		arcanum_id
	)
	var dirty_ids := {}
	var proto: Arcanum = state.arcana_catalog.get_proto(arcanum_id) if state.arcana_catalog != null else null
	for cid_variant in state.units.keys():
		var cid := int(cid_variant)
		_refresh_projected_status_cache_for(cid, [source_key])
		var unit: CombatantState = state.get_unit(cid)
		if unit == null or !unit.is_alive():
			continue
		if unit.combatant_data == null or unit.combatant_data.ai == null:
			continue
		if proto != null and proto.affects_others():
			dirty_ids[cid] = true
			continue
		if proto == null or !proto.affects_target(state, owner_id, cid):
			continue
		dirty_ids[cid] = true
	for cid_variant in dirty_ids.keys():
		var cid := int(cid_variant)
		_request_replan(cid)
		_request_intent_refresh(cid)
		_cancel_invalid_plan_immediately_if_needed(cid)
	if proto != null and proto.affects_others() and !dirty_ids.is_empty():
		if runtime != null and bool(is_main) and checkpoint_processor != null:
			var cp := checkpoint_processor
			if cp.has_dirty_planning() or cp.has_dirty_turn_order() or cp.has_dirty_outcome():
				runtime.request_projection_cleanup_flush()


func get_interceptors_for_hook(hook_kind: StringName) -> Array[Interceptor]:
	if state == null:
		return []
	return state.get_interceptors_for_hook(hook_kind)


func _dispatch_on_any_death_interceptor(interceptor: OnAnyDeathInterceptor, removal_ctx: RemovalContext) -> void:
	if interceptor == null or removal_ctx == null or state == null:
		return

	match interceptor.source_kind:
		Interceptor.SOURCE_KIND_STATUS_TOKEN:
			var owner = state.get_unit(int(interceptor.source_owner_id))
			if owner == null or !owner.is_alive() or owner.statuses == null or state.status_catalog == null:
				return

			var token: StatusToken = owner.statuses.get_status_token(interceptor.source_id, false)
			if token == null:
				return

			var proto := state.status_catalog.get_proto(interceptor.source_id)
			if proto == null or !proto.listens_for_any_death():
				return

			var ctx := SimStatusSystem.make_context(self, int(interceptor.source_owner_id), token)
			if ctx == null or !ctx.is_valid():
				return

			proto.on_any_death(ctx, removal_ctx)

		Interceptor.SOURCE_KIND_ARCANUM_ENTRY:
			var owner = state.get_unit(int(interceptor.source_owner_id))
			if owner == null or !owner.is_alive() or state.arcana == null or state.arcana_catalog == null:
				return

			var ctx := SimArcanaSystem.get_context(self, interceptor.source_id)
			if ctx == null or !ctx.is_valid() or ctx.proto == null:
				return
			if !ctx.proto.listens_for_any_death():
				return

			ctx.proto.on_any_death(ctx, removal_ctx)


func get_non_status_modifier_tokens_for_target(target_id: int, mod_type: Modifier.Type) -> Array[ModifierToken]:
	return SimArcanaSystem.get_modifier_tokens_for_target(self, target_id, mod_type)


func get_modifier_tokens_for_cid(
	target_id: int,
	mod_type: Modifier.Type
) -> Array[ModifierToken]:
	var tokens: Array[ModifierToken] = []

	# Battle-level globals (arcana)
	tokens.append_array(get_non_status_modifier_tokens_for_target(target_id, mod_type))

	var target: CombatantState = state.get_unit(target_id) if state != null else null
	if target == null or !target.is_alive():
		return tokens

	tokens.append_array(_get_effective_status_modifier_tokens_for_target(target_id, mod_type))
	return tokens


func _get_effective_status_modifier_tokens_for_target(
	target_id: int,
	mod_type: Modifier.Type
) -> Array[ModifierToken]:
	var out: Array[ModifierToken] = []
	if state == null or state.status_catalog == null:
		return out

	for ctx: SimStatusContext in get_effective_status_contexts_for_unit(target_id):
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
	return can_pay_card_cost(get_player_id(), card)


func get_effective_card_cost(source_id: int, card: CardData) -> int:
	if card == null:
		return 0

	var effective_cost := int(card.get_total_cost())
	if state == null or source_id <= 0:
		return maxi(effective_cost, 0)

	var total_discount := 0
	for status_ctx: SimStatusContext in get_effective_status_contexts_for_unit(int(source_id)):
		if status_ctx == null or !status_ctx.is_valid():
			continue
		var proto := status_ctx.proto
		if proto == null or !proto.affects_card_cost():
			continue
		total_discount += maxi(int(proto.get_card_cost_discount(status_ctx, card)), 0)

	return maxi(effective_cost - total_discount, 0)

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

func _request_group_layout_changed(
	group_index: int,
	before_order_ids: PackedInt32Array,
	after_order_ids: PackedInt32Array,
	reason: String = ""
) -> void:
	if checkpoint_processor == null:
		return
	if !_did_group_layout_change(before_order_ids, after_order_ids):
		return

	checkpoint_processor.request_group_layout_changed(
		int(group_index),
		before_order_ids,
		after_order_ids,
		String(reason)
	)

func _request_immediate_planning_flush_if_needed(target_id: int, proto: Status) -> void:
	if proto == null:
		return
	if !proto.affects_intent_legality():
		return
	_cancel_invalid_plan_immediately_if_needed(int(target_id))


func _cancel_invalid_plan_immediately_if_needed(target_id: int) -> void:
	if state == null or state.has_terminal_outcome() or target_id <= 0:
		return

	var u: CombatantState = state.get_unit(int(target_id))
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	ActionPlanner.ensure_ai_state_initialized(u)
	if bool(u.ai_state.get(Keys.PLANNING_NOW, false)) or bool(u.ai_state.get(Keys.IS_ACTING, false)):
		return
	if int(u.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) < 0:
		return
	if !bool(u.ai_state.get(Keys.FIRST_INTENTS_READY, false)):
		return

	var ctx := ActionPlanner.make_context(self, u)
	if ActionPlanner.is_current_plan_valid_sim(u.combatant_data.ai, ctx):
		return
	if !ActionPlanner.cancel_current_plan_sim(u.combatant_data.ai, ctx, true):
		return

	ActionIntentPresenter.emit_current_intent(self, int(target_id))

func _did_group_layout_change(
	before_order_ids: PackedInt32Array,
	after_order_ids: PackedInt32Array
) -> bool:
	if before_order_ids.size() != after_order_ids.size():
		return true

	for i in range(before_order_ids.size()):
		if int(before_order_ids[i]) != int(after_order_ids[i]):
			return true

	return false

func _request_turn_order_rebuild() -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_turn_order_rebuild()

func _request_outcome_check() -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_outcome_check()

func _on_status_changed(cid: int) -> void:
	_request_replan(int(cid))

func _untrack_auras_for_removed_combatant(removed_id: int) -> void:
	ProjectionChangeSystem.untrack_auras_from_removed_combatant(self, removed_id)

func _refresh_status_aura_projection(source_owner_id: int, status_id: StringName) -> void:
	ProjectionChangeSystem.sync_status_source(self, source_owner_id, status_id)



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

	# Prime status contexts once per hit so modifier and hook phases can reuse them.
	if state.is_alive(int(ctx.source_id)):
		get_effective_status_contexts_for_unit(int(ctx.source_id))
	get_effective_status_contexts_for_unit(int(ctx.target_id))
	
	ctx.phase = DamageContext.Phase.PRE_MODIFIERS
	var policy := int(ctx.modifier_policy)
	var apply_deal_modifiers := (policy & int(DamageContext.ModifierPolicy.SKIP_DEAL_MODIFIERS)) == 0
	var apply_take_modifiers := (policy & int(DamageContext.ModifierPolicy.SKIP_TAKE_MODIFIERS)) == 0

	var normal_amount := int(ctx.base_amount)
	if apply_deal_modifiers and int(ctx.deal_modifier_type) != int(Modifier.Type.NO_MODIFIER):
		normal_amount = SimModifierResolver.get_modified_value(
			self,
			int(normal_amount),
			ctx.deal_modifier_type,
			int(ctx.source_id)
		)
	if apply_take_modifiers and int(ctx.take_modifier_type) != int(Modifier.Type.NO_MODIFIER):
		normal_amount = SimModifierResolver.get_modified_value(
			self,
			int(normal_amount),
			ctx.take_modifier_type,
			int(ctx.target_id)
		)

	var banish_amount := int(ctx.base_banish_amount)
	if apply_deal_modifiers:
		banish_amount = SimModifierResolver.get_modified_value(
			self,
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

	if tgt.mortality == CombatantState.Mortality.BOUND or tgt.mortality == CombatantState.Mortality.WILD:
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

	var health_damage := 0

	var health_absorb_normal := mini(remaining_normal, maxi(int(tgt.health), 0))
	tgt.health = int(tgt.health) - health_absorb_normal
	remaining_normal -= health_absorb_normal
	health_damage += health_absorb_normal

	var health_absorb_banish := mini(remaining_banish, maxi(int(tgt.health), 0))
	tgt.health = int(tgt.health) - health_absorb_banish
	remaining_banish -= health_absorb_banish
	health_damage += health_absorb_banish

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
			int(ctx.health_damage),
			bool(ctx.was_lethal),
			int(ctx.before_health),
			int(ctx.after_health),
			ctx.event_extra if ctx.event_extra != null else {},
		)
	
	on_damage_applied(ctx)
	
	if bool(ctx.was_lethal):
		var removal_ctx = RemovalContext.new()
		removal_ctx.target_id = int(ctx.target_id)
		removal_ctx.removal_type = Removal.Type.DEATH
		removal_ctx.killer_id = int(ctx.source_id)
		removal_ctx.reason = "damage"
		removal_ctx.origin_card_uid = String(ctx.origin_card_uid)
		removal_ctx.origin_arcanum_id = ctx.origin_arcanum_id
		removal_ctx.event_extra = ctx.event_extra.duplicate() if ctx.event_extra != null else {}
		resolve_removal(removal_ctx)
	
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
		var removal_ctx = RemovalContext.new()
		removal_ctx.target_id = int(cid)
		removal_ctx.removal_type = Removal.Type.DEATH
		removal_ctx.reason = "change_max_health:" + String(reason)
		resolve_removal(removal_ctx)

func resolve_removal(ctx) -> void:
	if state == null or ctx == null:
		return
	if int(ctx.target_id) <= 0:
		return
	
	var u: CombatantState = state.get_unit(int(ctx.target_id))
	if u == null or !u.alive:
		return
	var removal_reason_label := _make_removal_reason_label(int(ctx.removal_type), String(ctx.reason))
	_maybe_release_reserved_card(u, int(ctx.overload_mod), removal_reason_label, ctx)

	var g := int(u.team)
	ctx.group_index = g
	ctx.before_order_ids = PackedInt32Array(state.groups[g].order) if g != -1 else PackedInt32Array()
	ctx.insert_index = ctx.before_order_ids.find(int(ctx.target_id))

	u.alive = false
	if g != -1:
		state.groups[g].remove(int(ctx.target_id))

	_sync_all_status_source_transformers(int(ctx.target_id))

	ctx.after_order_ids = PackedInt32Array(state.groups[g].order) if g != -1 else PackedInt32Array()
	_request_group_layout_changed(
		int(g),
		ctx.before_order_ids,
		ctx.after_order_ids,
		removal_reason_label
	)
	ActionLifecycleSystem.on_combatant_removal(self, ctx)
	
	unit_removed.emit(int(ctx.target_id), int(g), int(ctx.removal_type), String(ctx.reason))

	if writer != null:
		writer.emit_removed(
			int(ctx.killer_id),
			int(ctx.target_id),
			g,
			ctx.before_order_ids,
			ctx.after_order_ids,
			ctx.removal_type,
			String(ctx.reason),
			ctx.event_extra if ctx.event_extra != null else {}
		)

	ctx.removed = true
	_request_turn_order_rebuild()
	_request_outcome_check()

	if runtime != null:
		var reaction = RemovalDelayedReaction.new()
		reaction.removal_ctx = ctx
		reaction.any_death_interceptors = get_interceptors_for_hook(Interceptor.HOOK_ON_ANY_DEATH)
		reaction.source_reason = String(ctx.reason)
		reaction.origin_card_uid = String(ctx.origin_card_uid)
		reaction.origin_arcanum_id = ctx.origin_arcanum_id
		runtime.enqueue_delayed_reaction(reaction)
		if !runtime.is_in_strike_resolution():
			runtime.drain_delayed_reactions(DelayedReaction.Timing.AFTER_STRIKE)
	else:
		var any_death_interceptors := get_interceptors_for_hook(Interceptor.HOOK_ON_ANY_DEATH)
		SimStatusSystem.on_removal(self, ctx)
		SimArcanaSystem.on_removal(self, ctx)
		for interceptor_variant in any_death_interceptors:
			var interceptor := interceptor_variant as OnAnyDeathInterceptor
			if interceptor != null:
				interceptor.dispatch(self, ctx)


func resolve_move(ctx: MoveContext) -> void:
	if ctx == null or state == null:
		return
	if int(ctx.actor_id) <= 0:
		return

	# Determine which unit is physically repositioned.
	# Preferred pattern for new callers: set actor_id = initiating unit, target_id = unit to move.
	# Legacy pattern (backward compat): set actor_id = unit to move, leave target_id unset (0).
	# For positional moves (MOVE_TO_FRONT, MOVE_TO_BACK, INSERT_AT_INDEX):
	#   - if target_id is set, it is the unit to reposition (actor is the initiator)
	#   - otherwise fall back to actor_id for legacy callers that set actor_id = unit to move
	# For SWAP_WITH_TARGET, actor_id and target_id both participate in their own roles.
	var is_swap := int(ctx.move_type) == MoveContext.MoveType.SWAP_WITH_TARGET
	var move_unit_id := int(ctx.actor_id)
	if !is_swap and int(ctx.target_id) > 0:
		move_unit_id = int(ctx.target_id)

	var u := state.get_unit(move_unit_id)
	if u == null or !u.is_alive():
		return

	var g := int(u.team)
	if g < 0:
		return

	ctx.before_order_ids = PackedInt32Array(state.groups[g].order)
	match ctx.move_type:
		MoveContext.MoveType.MOVE_TO_FRONT:
			_move_id_to_index(g, move_unit_id, 0)
		MoveContext.MoveType.MOVE_TO_BACK:
			_move_id_to_index(g, move_unit_id, state.groups[g].order.size() - 1)
		MoveContext.MoveType.INSERT_AT_INDEX:
			_move_id_to_index(g, move_unit_id, int(ctx.index))
		MoveContext.MoveType.SWAP_WITH_TARGET:
			if int(ctx.target_id) > 0:
				_swap_ids(g, int(ctx.actor_id), int(ctx.target_id))
		_:
			pass

	ctx.after_order_ids = PackedInt32Array(state.groups[g].order)
	_request_group_layout_changed(
		int(g),
		ctx.before_order_ids,
		ctx.after_order_ids,
		String(ctx.reason if !ctx.reason.is_empty() else "move")
	)
	_request_turn_order_rebuild()

	if writer != null:
		var extra := {}
		if int(ctx.target_id) > 0:
			extra[Keys.TARGET_ID] = int(ctx.target_id)
		if int(ctx.index) >= 0:
			extra[Keys.TO_INDEX] = int(ctx.index)
		extra[Keys.GROUP_INDEX] = int(g)

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
	var first_apply := int(ctx.op) == int(Status.OP.APPLY)
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

	if !changed and !first_apply:
		# No effective mutation means no projection, status-hook, or intent side effects.
		return
	_invalidate_effective_status_context_cache()
	_sync_status_source_transformers(int(ctx.target_id), ctx.status_id)

	var status_ctx := SimStatusSystem.make_context(
		self,
		int(ctx.target_id),
		u.statuses.get_status_token(ctx.status_id, bool(ctx.pending))
	)
	if status_ctx != null and status_ctx.proto != null:
		status_ctx.proto.on_apply(status_ctx, ctx)

	if !SimStatusSystem.is_aura_proto(proto):
		_request_intent_refresh(int(ctx.target_id))
	
	if !SimStatusSystem.is_aura_proto(proto):
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
	
	var old_token: StatusToken = u.statuses.get_status_token(ctx.status_id, bool(ctx.pending))
	if old_token == null:
		return
	
	var proto := SimStatusSystem.get_proto(self, ctx.status_id)
	
	var before_i := int(old_token.intensity)
	var before_d := int(old_token.duration)
	
	var status_ctx := SimStatusSystem.make_context(self, int(ctx.target_id), old_token)
	u.statuses.remove_ctx(ctx)
	_invalidate_effective_status_context_cache()
	_sync_status_source_transformers(int(ctx.target_id), ctx.status_id)
	
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
	
	if status_ctx != null and status_ctx.proto != null:
		status_ctx.proto.on_remove(status_ctx, ctx)
	
	if !SimStatusSystem.is_aura_proto(proto):
		_request_intent_refresh(int(ctx.target_id))
	
	if !SimStatusSystem.is_aura_proto(proto):
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
	var before_order_ids := PackedInt32Array(state.groups[g].order)
	
	if is_player:
		state.groups[FRIENDLY].player_id = id
	
	var u := _make_unit_from_combatant_data(combatant_data, id, g, is_player, int(current_health_override))
	state.add_unit(u, g, int(insert_index))
	_sync_all_status_source_transformers(id)
	_refresh_projected_status_cache_for(id, [], true)
	_request_turn_order_rebuild()
	var after_order_ids := PackedInt32Array(state.groups[g].order)
	_request_group_layout_changed(int(g), before_order_ids, after_order_ids, "spawn")
	
	if writer != null:
		var proto := String(u.data_proto_path)
		var spec := _make_spawn_spec_from_data(combatant_data, u)
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
	var summon_ap_bonus := get_summon_card_ap_bonus(u.bound_card_uid)
	if summon_ap_bonus > 0:
		u.ap += summon_ap_bonus
	var summon_bonus := get_summon_card_max_health_bonus(u.bound_card_uid)
	if summon_bonus > 0:
		u.max_health += summon_bonus
		u.health += summon_bonus
	SimStatusSystem.on_summon_will_resolve(self, source_id, ctx, u)
	u.mortality = int(ctx.mortality) as CombatantState.Mortality
	u.type = CombatantView.Type.ALLY if g == 0 else CombatantView.Type.ENEMY
	
	state.add_unit(u, g, int(ctx.insert_index))
	_sync_all_status_source_transformers(id)
	_refresh_projected_status_cache_for(id, [], true)
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
	_request_group_layout_changed(
		int(g),
		ctx.before_order_ids,
		ctx.after_order_ids,
		String(ctx.reason if !ctx.reason.is_empty() else "summon")
	)
	
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


func count_bound_in_group(group_index: int) -> int:
	return count_mortality_in_group(group_index, CombatantState.Mortality.BOUND)


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

func can_pay_card_cost(source_id: int, card: CardData) -> bool:
	if state == null or state.resource == null or card == null:
		return false
	return int(state.resource.mana) >= int(get_effective_card_cost(source_id, card))

func spend_mana_for_card(ctx: ManaContext, card: CardData) -> bool:
	if state == null or state.resource == null or card == null or ctx == null:
		return false
	
	var source_id := int(ctx.source_id)
	var cost := int(get_effective_card_cost(source_id, card))
	card.ensure_uid()
	ctx.card_uid = String(card.uid)
	ctx.card_name = String(card.name)
	if cost <= 0:
		ctx.amount = 0
		ctx.mode = ManaContext.Mode.SPEND_FOR_CARD
		ctx.new_mana = int(state.resource.mana)
		set_mana(ctx, {
			Keys.CARD_UID: ctx.card_uid,
			Keys.CARD_NAME: ctx.card_name,
			Keys.AMOUNT: 0,
		})
		_consume_card_cost_statuses_after_play(source_id, card)
		return true
	
	if int(state.resource.mana) < cost:
		return false
	
	ctx.amount = cost
	ctx.mode = ManaContext.Mode.SPEND_FOR_CARD
	ctx.new_mana = int(state.resource.mana) - cost
	
	set_mana(ctx, {
		Keys.CARD_UID: ctx.card_uid,
		Keys.CARD_NAME: ctx.card_name,
		Keys.AMOUNT: int(cost),
	})
	_consume_card_cost_statuses_after_play(source_id, card)
	
	return true


func _consume_card_cost_statuses_after_play(source_id: int, card: CardData) -> void:
	if state == null or card == null or source_id <= 0:
		return

	var removals: Array[Dictionary] = []
	for status_ctx: SimStatusContext in get_effective_status_contexts_for_unit(int(source_id)):
		if status_ctx == null or !status_ctx.is_valid():
			continue
		var proto := status_ctx.proto
		if proto == null or !proto.affects_card_cost():
			continue
		if !proto.consume_on_card_play(status_ctx, card):
			continue
		removals.append({
			"status_id": status_ctx.get_status_id(),
			"pending": status_ctx.is_pending(),
		})

	for removal in removals:
		var remove_ctx := StatusContext.new()
		remove_ctx.source_id = int(source_id)
		remove_ctx.target_id = int(source_id)
		remove_ctx.status_id = removal.get("status_id", &"")
		remove_ctx.pending = bool(removal.get("pending", false))
		remove_status(remove_ctx)

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
		var removal_ctx = RemovalContext.new()
		removal_ctx.target_id = enemy_id
		removal_ctx.removal_type = Removal.Type.DEATH
		removal_ctx.reason = reason
		resolve_removal(removal_ctx)

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
		self,
		amount,
		int(ctx.deal_modifier_type),
		int(ctx.source_id)
	)
	amount = SimModifierResolver.get_modified_value(
		self,
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
		Keys.AP: int(u.ap),
		Keys.PROTO_PATH: String(combatant_data.resource_path),
		Keys.ART_UID: String(combatant_data.character_art_uid),
		Keys.ART_FACES_RIGHT: bool(combatant_data.facing_right),
		Keys.HEIGHT: int(combatant_data.height),
		Keys.COLOR_TINT: combatant_data.color_tint as Color,
		Keys.MORTALITY: int(u.mortality),
		Keys.HAS_SUMMON_RESERVE_CARD: String(u.bound_card_uid) != "",
	}


func _maybe_release_reserved_card(
	u: CombatantState,
	overload_mod: int,
	reason: String,
	removal_ctx: RemovalContext = null
) -> void:
	if u == null:
		return
	var uid := String(u.bound_card_uid)
	if uid == "":
		return

	if removal_ctx != null:
		removal_ctx.released_reserve_card_uid = uid
	
	if writer != null:
		writer.emit_summon_reserve_released(int(u.id), uid, overload_mod, String(reason))
	
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

		var removal_ctx = RemovalContext.new()
		removal_ctx.target_id = faded_id
		removal_ctx.removal_type = Removal.Type.FADE
		removal_ctx.reason = fade_reason
		resolve_removal(removal_ctx)


func _get_mortality_cap_fade_reason(mortality: int) -> String:
	match int(mortality):
		int(CombatantState.Mortality.BOUND):
			return "summon_over_cap_bound"
		int(CombatantState.Mortality.WILD):
			return "summon_over_cap_wild"
		_:
			return "summon_over_cap"


func _make_removal_reason_label(removal_type: int, reason: String) -> String:
	var type_label := "death" if int(removal_type) == int(Removal.Type.DEATH) else "fade"
	var prefix := "removal:%s" % type_label
	if String(reason).is_empty():
		return prefix
	return "%s:%s" % [prefix, String(reason)]


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


func _refresh_projected_status_cache_for(
	id: int,
	source_keys: Array[String] = [],
	full_rebuild := false
) -> void:
	_invalidate_effective_status_context_cache()
	SimStatusSystem.refresh_cached_projected_statuses_for_unit(
		self,
		int(id),
		source_keys,
		bool(full_rebuild)
	)


func _refresh_all_projected_status_caches() -> void:
	if state == null:
		return
	for cid in state.units.keys():
		_refresh_projected_status_cache_for(int(cid), [], true)


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
