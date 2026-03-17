# sim_battle_api.gd

class_name SimBattleAPI extends RefCounted

const FRIENDLY := 0
const ENEMY := 1

var status_catalog: StatusCatalog
#var status_catalog: StatusCatalog
var state: BattleState
var checkpoint_processor: CheckpointProcessor
#var alloc_id: Callable = Callable() # () -> int
var on_summoned: Callable = Callable() # (summoned_id: int, group_index: int) -> void
var on_unit_removed: Callable = Callable() # (combat_id: int, group_index: int, reason: String) -> void
var pending_discard: DiscardRequest = null

var scopes: BattleScopeManager
var writer: BattleEventWriter

func _init(_state: BattleState) -> void:
	state = _state

#var battle_seed: int = 0

# --------------------------
# Queries / helpers
# --------------------------

func is_alive(combat_id: int) -> bool:
	return state != null and state.is_alive(combat_id)

func get_group(combat_id: int) -> int:
	var u := state.get_unit(combat_id)
	return u.team if u else -1

func get_team(combat_id: int) -> int:
	# team == group for now
	return get_group(combat_id)

func get_opposing_group(group_index: int) -> int:
	return 1 - clampi(group_index, 0, 1)

func get_combatants_in_group(group_index: int, allow_dead := false) -> Array[int]:
	var ids: Array[int] = []
	if state == null:
		return ids

	group_index = clampi(group_index, 0, 1)
	for id in state.groups[group_index].order:
		if allow_dead or state.is_alive(id):
			ids.append(int(id))
	return ids

func get_front_combatant_id(group_index: int) -> int:
	var ids := get_combatants_in_group(group_index, false)
	return ids[0] if ids.size() > 0 else 0

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
	ids.erase(combat_id)
	return ids

func get_rank_in_group(combat_id: int) -> int:
	var g := get_group(combat_id)
	if g == -1:
		return -1
	return state.groups[g].index_of(combat_id)

func get_player_id() -> int:
	if !state or !state.groups:
		return -1
	return state.groups[FRIENDLY].player_id

func has_status(combat_id: int, status_id: StringName) -> bool:
	var u := state.get_unit(combat_id)
	if u == null or !u.is_alive():
		return false
	return u.statuses.has(status_id)


func find_marked_ranged_redirect_target(attacker_id: int) -> int:
	for id in get_enemies_of(attacker_id):
		if has_status(id, Keys.STATUS_MARKED):
			return id
	return 0


func get_targets_for_attack_sequence(ai_ctx) -> Array:
	#var attacker_id := 0
	if ai_ctx == null:
		return []

	var attacker_id := int(ai_ctx.cid) if ai_ctx and ("cid" in ai_ctx) else 0
	if attacker_id <= 0 and ai_ctx.combatant:
		attacker_id = int(ai_ctx.combatant.combat_id)
	if attacker_id <= 0 and ai_ctx.combatant_data:
		attacker_id = int(ai_ctx.combatant_data.combat_id)

	if attacker_id <= 0:
		return []

	# AttackTargeting should be API-driven already.
	return AttackTargeting.get_target_ids(self, attacker_id, ai_ctx.params)


# --------------------------
# Core verbs (SYNC)
# --------------------------

#func resolve_damage(ctx: DamageContext) -> void:
	#resolve_damage_immediate(ctx)

func resolve_attack(ctx: NPCAIContext) -> bool:
	print("sim_battle_api.gd resolve_attack() IS THIS ACTUALLY USED?")
	return SimAttackRunner.run(self, ctx)

func resolve_damage_immediate(ctx: DamageContext) -> int:
	#print("sim_battle_api.gd resolve_damage_immediate() dmg: ", ctx.base_amount)
	if ctx == null or state == null:
		return 0

	# --- PREP / VALIDATION ---
	if int(ctx.base_amount) <= 0:
		ctx.amount = 0
		return 0

	if !state.is_alive(int(ctx.target_id)):
		ctx.amount = 0
		return 0

	ctx.phase = DamageContext.Phase.PRE_MODIFIERS
	ctx.amount = int(ctx.base_amount)

	# --- APPLY MODIFIERS ---
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

	# --- APPLY TO STATE ---
	var tgt: CombatantState = state.get_unit(int(ctx.target_id))
	if tgt == null:
		ctx.amount = 0
		return 0

	var remaining := int(ctx.amount)
	var before_health := int(tgt.health)

	# Armor first
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

	# Emit damage event BEFORE death sequence
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

	# Hooks (AI memory, status reactions, etc.)
	on_damage_applied(ctx)
	
	
	# --- DEATH PIPELINE ---
	# IMPORTANT: don't remove from order here; do it through resolve_death/SimDeathRunner
	if bool(ctx.was_lethal):
		resolve_death(int(ctx.target_id), "damage", int(ctx.source_id))

	return int(ctx.amount)


# Overload-like signature (Godot doesn't support overloads; use defaults)
func resolve_death(combat_id: int, reason := "", killer_id: int = 0) -> void:
	if state == null or combat_id <= 0:
		return
	
	var u: CombatantState = state.get_unit(combat_id)
	if u == null:
		return
	
	# Idempotent: if already removed from group order, no-op (still "exists" in units dict)
	if !u.alive:
		return
	
	_maybe_release_soulbound_reserve(u, "fade:" + reason)
	# Run the death sequence (beats + final removal + DIED event)
	SimDeathRunner.run(self, combat_id, killer_id, String(reason))

func count_summons_in_group(group_index: int) -> int:
	if state == null:
		return 0
	group_index = clampi(group_index, 0, 1)

	var n := 0
	for id in state.groups[group_index].order:
		var u: CombatantState = state.get_unit(int(id))
		if u == null or !u.is_alive():
			continue
		# Match your old convention: team==1 means summon
		if u.combatant_data != null and int(u.combatant_data.team) == 1:
			n += 1
	return n

func fade_unit(combat_id: int, reason: String = "fade") -> void:
	var u: CombatantState = state.get_unit(combat_id)
	if u == null or !u.alive:
		return
	_maybe_release_soulbound_reserve(u, "fade:" + reason)
	var g := int(u.team)
	var before := PackedInt32Array(state.groups[g].order)

	if writer != null:
		writer.scope_begin(Scope.Kind.FADE, "fade_unit", combat_id)

	# Mutate state immediately (VIEW will animate against events)
	u.alive = false
	if g != -1:
		state.groups[g].remove(combat_id)
	if on_unit_removed.is_valid():
		on_unit_removed.call(int(combat_id), int(g), "fade:" + String(reason))
	var after_order_ids := PackedInt32Array(state.groups[g].order) if g != -1 else PackedInt32Array()

	if writer != null:
		writer.emit_faded(combat_id, g, before, after_order_ids, reason)
		writer.scope_end()

func _maybe_release_soulbound_reserve(u: CombatantState, reason: String) -> void:
	if u == null:
		return
	if int(u.mortality) != int(CombatantView.Mortality.SOULBOUND):
		return
	var uid := String(u.bound_card_uid) if ("bound_card_uid" in u) else ""
	if uid == "":
		return
	if writer != null:
		writer.emit_summon_reserve_released(int(u.id), uid, reason)
	# prevent double-release
	u.bound_card_uid = ""

func apply_status(ctx: StatusContext) -> void:
	if ctx == null or state == null:
		return

	#ctx.hydrate_ids()
	if ctx.target_id <= 0:
		return

	var u := state.get_unit(ctx.target_id)
	if u == null or !u.is_alive():
		return

	if ctx.status_id == &"":
		return

	# Default intensity if omitted
	if int(ctx.intensity) == 0:
		ctx.intensity = 1

	# IMPORTANT: let StatusState decide APPLY vs CHANGE
	var changed := u.statuses.add_or_reapply_ctx(ctx)
	ctx.applied = changed or (ctx.op == Status.OP.APPLY)

	# If nothing changed, you can choose to not emit anything.
	# I recommend: emit only if APPLY or actual change.
	if writer != null and (ctx.op == Status.OP.APPLY or changed):
		writer.emit_status(
			int(ctx.source_id),
			int(ctx.target_id),
			ctx.status_id,
			int(ctx.op),
			int(ctx.intensity), # request (or requested delta)
			int(ctx.duration),  # request (or requested delta)
			{
				Keys.DELTA_INTENSITY: int(ctx.delta_intensity),
				Keys.DELTA_DURATION: int(ctx.delta_duration),
				Keys.BEFORE_INTENSITY: int(ctx.before_intensity),
				Keys.BEFORE_DURATION: int(ctx.before_duration),
				Keys.AFTER_INTENSITY: int(ctx.after_intensity),
				Keys.AFTER_DURATION: int(ctx.after_duration),
			}
		)

	_rebuild_modifier_cache_for(ctx.target_id)

	var proto := _get_status_proto(ctx.status_id)
	if _is_aura_proto(proto):
		_request_intent_refresh_targets_for_aura(int(ctx.target_id), proto)
	else:
		_request_intent_refresh(int(ctx.target_id))
	_on_status_changed(ctx.target_id)


func remove_status(ctx: StatusContext) -> void:
	if ctx == null or state == null:
		return
	if ctx.target_id <= 0:
		return

	var u := state.get_unit(ctx.target_id)
	if u == null:
		return
	if ctx.status_id == &"":
		return

	var proto := _get_status_proto(ctx.status_id)
	var old_stack: StatusStack = u.statuses.get_status_stack(ctx.status_id)

	var before_i := 0
	var before_d := 0
	if old_stack != null:
		before_i = int(old_stack.intensity)
		before_d = int(old_stack.duration)

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

	_rebuild_modifier_cache_for(ctx.target_id)
	if _is_aura_proto(proto):
		_request_intent_refresh_targets_for_aura(int(ctx.target_id), proto)
	else:
		_request_intent_refresh(int(ctx.target_id))
	_on_status_changed(ctx.target_id)

func _request_intent_refresh_all() -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_intent_refresh_all()
		return

	if state == null:
		return
	for k in state.units.keys():
		var cid := int(k)
		_request_intent_refresh(cid)

func _on_status_changed(cid: int) -> void:
	_request_replan(cid)

func _request_replan(cid: int) -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_replan(int(cid))
		return

	# Fallback during migration
	var u: CombatantState = state.get_unit(int(cid))
	if u == null:
		return
	ActionPlanner._ensure_ai_state_initialized(u)
	u.ai_state[&"replan_dirty"] = true

func spawn_from_data(combatant_data: CombatantData, group_index: int, insert_index: int = -1, is_player := false) -> int:
	if combatant_data == null or state == null:
		return 0
	
	var id := state.alloc_id()
	if is_player:
		state.groups[FRIENDLY].player_id = id
	var u := CombatantState.new()
	if is_player:
		u.type = CombatantView.Type.PLAYER
	else:
		u.type = CombatantView.Type.ALLY if group_index == 0 else CombatantView.Type.ENEMY
	u.mortality = CombatantView.Mortality.MORTAL
	u.id = id
	u.rng = RNG.new(RNGUtil.mix_seed(state.battle_seed, u.id))
	u.combatant_data = combatant_data
	u.init_from_combatant_data(combatant_data)
	
	if combatant_data.resource_path != "":
		u.data_proto_path = String(combatant_data.resource_path)
	
	var g := clampi(group_index, 0, 1)
	#if insert_index < 0:
		#
	state.add_unit(u, g, int(insert_index))
	
	if writer != null:
		var proto := String(u.data_proto_path)
		var spec := {
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
		var after_order_ids = PackedInt32Array(state.groups[g].order)
		writer.emit_spawned(id, g, int(insert_index), after_order_ids, proto, spec, is_player)
	
	return id

func summon(ctx: SummonContext) -> void:
	if ctx == null or state == null:
		return
	if ctx.summon_data == null:
		push_warning("SimBattleAPI.summon: missing summon_data")
		return

	var g := clampi(ctx.group_index, 0, 1)
	var source_id := int(ctx.source_id) if ("source_id" in ctx) else 0

	# Snapshot for WINDUP positioning:
	# - If caller provided windup_order_ids, use it (summon-replace case).
	# - Else use current order (normal summon case).
	var windup_order := ctx.windup_order_ids
	if windup_order == null or windup_order.is_empty():
		windup_order = PackedInt32Array(state.groups[g].order)
		
	# Allocate + add unit
	var id := state.alloc_id()
	ctx.summon_data.combat_id = id
	
	## --- Beat 1: SUMMON_WINDUP ---
	#if writer != null:
		#writer.emit_summon_windup(source_id, g, int(ctx.insert_index), 1, {
			#Keys.SUMMONED_ID: int(id),
			#Keys.BEFORE_ORDER_IDS: windup_order,      # <= critical
			#Keys.WINDUP_LAYOUT_COUNT: windup_order.size(),
			#Keys.REASON: String(ctx.reason)
		#})
	
	
	
	var u := CombatantState.new()
	u.id = id
	u.rng = RNG.new(RNGUtil.mix_seed(state.battle_seed, u.id))
	u.combatant_data = ctx.summon_data
	u.init_from_combatant_data(ctx.summon_data)
	if ctx.summon_data.resource_path != "":
		u.data_proto_path = String(ctx.summon_data.resource_path)
	
	u.bound_card_uid = String(ctx.bound_card_uid)
	u.type = CombatantView.Type.ALLY if g == 0 else CombatantView.Type.ENEMY
	u.mortality = ctx.mortality
	state.add_unit(u, g, int(ctx.insert_index))
	
	if writer != null:
		var spec := {
			Keys.COMBATANT_NAME: String(ctx.summon_data.name),
			Keys.MAX_HEALTH: int(ctx.summon_data.max_health),
			Keys.HEALTH: int(ctx.summon_data.health),
			Keys.MAX_MANA: int(ctx.summon_data.max_mana),
			Keys.APM: int(ctx.summon_data.apm),
			Keys.APR: int(ctx.summon_data.apr),
			Keys.PROTO_PATH: String(ctx.summon_data.resource_path),
			Keys.ART_UID: String(ctx.summon_data.character_art_uid),
			Keys.ART_FACES_RIGHT: bool(ctx.summon_data.facing_right),
			Keys.HEIGHT: int(ctx.summon_data.height),
			Keys.COLOR_TINT: ctx.summon_data.color_tint as Color,
			Keys.MORTALITY: u.mortality,
		}
		
		var after_order_ids := PackedInt32Array(state.groups[g].order)
		#print("sim_battle_api.gd summon() art uid: ", ctx.summon_data.character_art_uid)
		writer.emit_summoned(source_id, id, g, int(ctx.insert_index), windup_order, after_order_ids, u.data_proto_path, spec, ctx.reason, ctx.bound_card_uid)
		#
		#writer.emit_summon_followthrough(source_id, g, int(ctx.insert_index), 1, {
			#Keys.SUMMONED_ID: int(id),
			#Keys.AFTER_ORDER_IDS: after_order_ids,
		#})

	ctx.summoned_id = id
	if on_summoned.is_valid():
		on_summoned.call(id, g)

	_request_replan(id)
	_request_intent_refresh(id)

func count_soulbound_in_group(group_index: int) -> int:
	if state == null:
		return 0
	group_index = clampi(group_index, 0, 1)
	
	var n := 0
	for id in state.groups[group_index].order:
		var u: CombatantState = state.get_unit(int(id))
		if u == null or !u.is_alive():
			continue
		#print("sim_battle_api.gd count_soulbound_in_group() cid: %s, mortality: %s" % [id, CombatantView.Mortality.keys()[u.mortality]])
		if u.mortality == CombatantView.Mortality.SOULBOUND:
			n += 1
	return n

func resolve_move(ctx: MoveContext) -> void:
	if ctx == null or state == null:
		return
	if ctx.actor_id <= 0:
		return
	var u := state.get_unit(ctx.actor_id)
	if u == null or !u.is_alive():
		return
	
	var g := u.team
	if g < 0:
		return
	
	# Snapshot before
	ctx.before_order_ids = PackedInt32Array(state.groups[g].order)
	
	match ctx.move_type:
		MoveContext.MoveType.MOVE_TO_FRONT:
			_move_id_to_index(g, ctx.actor_id, 0)
		MoveContext.MoveType.MOVE_TO_BACK:
			_move_id_to_index(g, ctx.actor_id, state.groups[g].order.size() - 1)
		MoveContext.MoveType.INSERT_AT_INDEX:
			_move_id_to_index(g, ctx.actor_id, ctx.index)
		MoveContext.MoveType.SWAP_WITH_TARGET:
			if ctx.target_id > 0:
				_swap_ids(g, ctx.actor_id, ctx.target_id)
		_:
			pass

	# Snapshot after
	ctx.after_order_ids = PackedInt32Array(state.groups[g].order)
	
	if writer != null:
		writer.scope_begin(Scope.Kind.MOVE, "actor=%d" % int(ctx.actor_id), int(ctx.actor_id))
		var extra := {}
		if int(ctx.target_id) > 0:
			extra[Keys.TARGET_ID] = int(ctx.target_id)
		if int(ctx.index) >= 0:
			extra[Keys.TO_INDEX] = int(ctx.index)
		writer.emit_moved(int(ctx.actor_id), int(ctx.move_type), ctx.before_order_ids, ctx.after_order_ids, extra)
		writer.scope_end()

func apply_attack_now(spec: SimAttackSpec) -> bool:
	if spec == null or state == null:
		return false
	if spec.attacker_id <= 0 or !is_alive(spec.attacker_id):
		return false
	var ai_ctx := NPCAIContext.new()
	ai_ctx.api = self
	ai_ctx.cid = spec.attacker_id
	ai_ctx.combatant_state = state.get_unit(spec.attacker_id)
	#ai_ctx.combatant_data = api. #ctx.resolved.combatant_datas[0]
	#ai_ctx.battle_scene = null
	ai_ctx.state = {}
	ai_ctx.params = {}
	ai_ctx.forecast = false
	
	if spec.param_models:
		for m in spec.param_models:
			if m:
				m.change_params_sim(ai_ctx)
	return resolve_attack(ai_ctx)

# --------------------------
# Damage pipeline hooks
# --------------------------

func modify_damage_amount(ctx: DamageContext, base: int) -> int:
	var amount := base
	if state == null or ctx == null:
		return amount
	
	var src := state.get_unit(ctx.source_id)
	var tgt := state.get_unit(ctx.target_id)
	
	# Deal-side cache
	if src and src.modifiers:
		amount = src.modifiers.apply(ctx.deal_modifier_type, amount)
	
	# Take-side cache
	if tgt and tgt.modifiers:
		amount = tgt.modifiers.apply(ctx.take_modifier_type, amount)

	return amount

func on_damage_applied(ctx: DamageContext) -> void:
	#print("sim_battle_api.gd on_damage_applied()")
	if state == null or ctx == null:
		return

	var tid := int(ctx.target_id)
	var u: CombatantState = state.get_unit(tid)
	if u == null:
		return
	
	# NEW temporary hack: event-based status reactions (SIM)
	SimStatusEventRunner.on_damage_taken(self, ctx)
	
	if !u.is_alive():
		return
	
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	# Update AI memory fields similar to LIVE (optional but helpful for parity)
	if u.ai_state == null:
		u.ai_state = {}
	u.ai_state[ActionPlanner.DMG_SINCE_LAST_TURN] = int(u.ai_state.get(ActionPlanner.DMG_SINCE_LAST_TURN, 0)) + int(ctx.health_damage)

	# If not acting, let it re-evaluate conditions
	# Later: redo this so damage dirties the state
	_request_replan(tid)

func on_card_played(ctx: CardActionContextSim) -> void:
	if ctx == null or ctx.card_data == null:
		return
	if writer == null:
		return
	
	if ctx.emitted_card_played:
		return
	ctx.emitted_card_played = true
	
	ctx.card_data.ensure_uid()

	writer.scope_begin(Scope.Kind.CARD, "uid=%s %s" % [str(ctx.card_data.uid), String(ctx.card_data.name)], int(ctx.source_id))

	var targets: Array[int] = []
	if ctx.resolved != null:
		for id in ctx.resolved.fighter_ids:
			targets.append(int(id))

	var insert_index := (ctx.resolved.insert_index if ctx.resolved != null else -1)

	if writer != null:
		writer.emit_card_played(ctx)

func on_card_finished(ctx: CardActionContextSim) -> void:
	if writer != null:
		writer.scope_end() # card scope

func plan_intent(cid: int, allow_hooks := true, clear_dirty := true) -> void:
	var u: CombatantState = state.get_unit(int(cid))
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	ActionPlanner._ensure_ai_state_initialized(u)
	u.ai_state[ActionPlanner.FIRST_INTENTS_READY] = true

	if bool(u.ai_state.get(&"planning_now", false)) or bool(u.ai_state.get(ActionPlanner.IS_ACTING, false)):
		u.ai_state[&"replan_dirty"] = true
		return

	u.ai_state[&"planning_now"] = true

	var ctx_ai := _make_ai_ctx(u)
	ActionPlanner.ensure_valid_plan_sim(u.combatant_data.ai, ctx_ai, allow_hooks)

	u.ai_state[&"planning_now"] = false
	if clear_dirty:
		#print("plan_intent() clearing dirty")
		u.ai_state[&"replan_dirty"] = false

func plan_intents() -> void:
	for cid in state.units.keys():
		plan_intent(cid)
	
func _request_intent_refresh(cid: int) -> void:
	if checkpoint_processor != null:
		checkpoint_processor.request_intent_refresh(int(cid))
		return

	var u: CombatantState = state.get_unit(cid)
	if u == null:
		return
	ActionPlanner._ensure_ai_state_initialized(u)
	u.ai_state[&"intent_dirty"] = true

func has_pending_discard() -> bool:
	return pending_discard != null

func request_player_discard(req: DiscardRequest) -> void:
	if req == null:
		return
	# If one is already pending, do NOT stack silently.
	# Either ignore or overwrite; I recommend ignore + warn during dev.
	if pending_discard != null:
		push_warning("SimBattleAPI.request_player_discard(): discard already pending")
		return

	pending_discard = req

	# Emit an event so VIEW can open the discard modal.
	# You already have a DISCARD mode in the handler, so add an event type:
	if writer != null:
		writer.emit_discard_requested(req)

func resolve_player_discard(selected_card_uids: Array[String]) -> void:
	if pending_discard == null:
		push_warning("SimBattleAPI.resolve_player_discard(): no pending discard")
		return

	var req := pending_discard
	pending_discard = null

	# TODO: mutate SIM hand/deck state here (whatever your SIM model is).
	# For now, just emit a resolution event so playback is deterministic.
	if writer != null:
		writer.emit_discard_resolved(req, selected_card_uids)

# --------------------------
# Internal helpers
# --------------------------

func _move_id_to_index(group_index: int, id: int, new_index: int) -> void:
	var g := state.groups[group_index]
	var old := g.index_of(id)
	if old == -1:
		return
	g.remove(id)
	new_index = clampi(new_index, 0, g.order.size())
	g.add(id, new_index)

func _swap_ids(group_index: int, a: int, b: int) -> void:
	var g := state.groups[group_index]
	var ai := g.index_of(a)
	var bi := g.index_of(b)
	if ai == -1 or bi == -1 or ai == bi:
		return
	# swap in PackedInt32Array
	var tmp := g.order[ai]
	g.order[ai] = g.order[bi]
	g.order[bi] = tmp

func _rebuild_modifier_cache_for(_id: int) -> void:
	# Placeholder: this is where you’ll translate StatusState -> ModifierCache.
	# For now, keep caches empty or rebuild from a simple ruleset.
	pass

func _fire_opposing_group_start_for(cid: int) -> void:
	var u: CombatantState = state.get_unit(cid)
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	ActionPlanner._ensure_ai_state_initialized(u)
	u.ai_state[ActionPlanner.FIRST_INTENTS_READY] = true

	# Ensure valid plan BEFORE hook fire
	var ctx := _make_ai_ctx(u)
	ActionPlanner.ensure_valid_plan_sim(u.combatant_data.ai, ctx, true)

	# Telegraphed intent-time effects should only commit once per cycle
	if bool(u.ai_state.get("telegraph_committed", false)):
		return

	var idx := int(u.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	#print("sim_battle_api.gd _fire_opposing_group_start_for( planned cid: %s, idx: %s)" % [cid, idx])
	var action := ActionPlanner._get_action_by_idx(u.combatant_data.ai, idx)
	if action == null:
		return

	for m: IntentLifecycleModel in action.intent_lifecycle_models:
		if m:
			m.on_opposing_group_start_sim(ctx)

	u.ai_state["telegraph_committed"] = true


func _fire_my_group_end_for(cid: int) -> void:
	var u: CombatantState = state.get_unit(cid)
	if u == null:
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	ActionPlanner._ensure_ai_state_initialized(u)
	var ctx := _make_ai_ctx(u)

	var idx := int(u.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	var action := ActionPlanner._get_action_by_idx(u.combatant_data.ai, idx)
	if action == null:
		return

	for m: IntentLifecycleModel in action.intent_lifecycle_models:
		if m:
			m.on_my_group_end_sim(ctx)


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

# --------------------------
# Turn Lifecycle
# --------------------------

func on_group_turn_begin(group_index: int) -> void:
	if state == null:
		return

	SimStatusLifecycleRunner.on_group_turn_begin(self, group_index)

	# keep your opposing-group start flow (but remove the plan_intents/flush_replans here; see section 4)
	var opposing_group := get_opposing_group(group_index)

	# Ensure plans exist BEFORE hooks for the opposing group
	for cid in get_combatants_in_group(opposing_group, false):
		plan_intent(int(cid), true, false) # allow_hooks=true, clear_dirty=false

	for cid in get_combatants_in_group(opposing_group, false):
		_fire_opposing_group_start_for(int(cid))

func on_group_turn_end(group_index: int) -> void:
	if state == null:
		return

	SimStatusLifecycleRunner.on_group_turn_end(self, group_index)

	for cid in get_combatants_in_group(group_index, true):
		_fire_my_group_end_for(int(cid))

	for cid in get_combatants_in_group(group_index, true):
		var u := state.get_unit(int(cid))
		if u and u.ai_state:
			u.ai_state["telegraph_committed"] = false

func _get_status_proto(id: StringName) -> Status:
	# Prefer API catalog (you said it exists on the parent BattleAPI)
	if status_catalog != null:
		return status_catalog.get_proto(id)

	# Fallback: state catalog (helps preview clones if needed)
	if state != null and state.status_catalog != null:
		return state.status_catalog.get_proto(id)

	return null


func _is_aura_proto(proto: Status) -> bool:
	if proto == null:
		return false
	# If Aura extends Status, this is the simplest / strongest check.
	if proto is Aura:
		return true
	# Backstop: “affects others” semantics
	if proto.affects_others():
		return true
	# Another backstop: contributes modifier tokens that are aura-scoped
	if proto.contributes_modifier():
		var types := proto.get_contributed_modifier_types()
		for t in types:
			# If it contributes anything, and you’ve authored it as an Aura-like status, treat as aura
			# (optional; remove if you want ONLY Aura subclass)
			pass
	return false





func _request_intent_refresh_targets_for_aura(source_id: int, proto: Status) -> void:
	# Conservative + correct: refresh all (fast to implement, correct output)
	# If you later want it tighter, replace this with tag-based routing.
	_request_intent_refresh_all()

func get_n_combatants_in_group(group_index: int, allow_dead := false) -> int:
	return get_combatants_in_group(group_index, allow_dead).size()

func run_status_proc(_target_id: int, _proc_type: Status.ProcType) -> void:
	pass

# --------------------------
# Core verbs (queued in live)
# --------------------------

func resolve_heal(_ctx: HealContext) -> void:
	pass

func resolve_attack_now(_ctx: AttackNowContext) -> void:
	pass


# --------------------------
# DamageResolver hooks
# --------------------------

func apply_damage_amount(_ctx: DamageContext, _amount: int) -> void:
	pass

func play_sfx(sound: Sound) -> void:
	if sound:
		SFXPlayer.play(sound)

func get_status_intensity(combat_id: int, status_id: StringName) -> int:
	return -1

func get_player_pos_delta(combat_id: int) -> int:
	# live: use battle_scene.get_player_pos_delta(fighter)
	# sim: compute based on rank relative to player id
	return 0
