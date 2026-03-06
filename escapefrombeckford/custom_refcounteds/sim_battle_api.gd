# sim_battle_api.gd

class_name SimBattleAPI extends BattleAPI

const FRIENDLY := 0
const ENEMY := 1

var state: BattleState
#var alloc_id: Callable = Callable() # () -> int
var on_summoned: Callable = Callable() # (summoned_id: int, group_index: int) -> void

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
	return SimAttackRunner.run(self, ctx)

# sim_battle_api.gd
func resolve_damage_immediate(ctx: DamageContext) -> int:
	if !ctx:
		return 0
	
	# --- PREP / VALIDATION ---
	if ctx.base_amount <= 0:
		ctx.amount = 0
		return 0
	
	if !state.is_alive(ctx.target_id):
		ctx.amount = 0
		return 0
	
	ctx.phase = DamageContext.Phase.PRE_MODIFIERS
	ctx.amount = ctx.base_amount
	
	# --- APPLY MODIFIERS (one at a time; cid-based) ---
	# 1) attacker modifies damage dealt
	#print("sim_battle_api.gd resolve_damage_immediate() pre dealt amt: ", ctx.amount)
	ctx.amount = SimModifierResolver.get_modified_value(
		state,
		ctx.amount,
		ctx.deal_modifier_type,
		ctx.source_id
	)
	#print("sim_battle_api.gd resolve_damage_immediate() pre taken amt: ", ctx.amount)
	# 2) defender modifies damage taken
	ctx.amount = SimModifierResolver.get_modified_value(
		state,
		ctx.amount,
		ctx.take_modifier_type,
		ctx.target_id
	)
	#print("sim_battle_api.gd resolve_damage_immediate() post dealt amt: ", ctx.amount)
	ctx.amount = maxi(ctx.amount, 0)
	ctx.phase = DamageContext.Phase.POST_MODIFIERS
	
	# Optional: statuses that care about "final damage about to be applied"
	# _emit_damage_event(ctx, "post_modifiers")
	
	# --- APPLY TO STATE ---
	var tgt := state.get_unit(ctx.target_id)
	if !tgt:
		ctx.amount = 0
		return 0
	
	var remaining := ctx.amount
	var before_health := tgt.health
	# Armor first (if that’s your rule)
	var armor_damage := mini(remaining, maxi(tgt.armor, 0))
	tgt.armor -= armor_damage
	remaining -= armor_damage
	
	var health_damage := mini(remaining, maxi(tgt.health, 0))
	tgt.health -= health_damage
	remaining -= health_damage
	
	ctx.armor_damage = armor_damage
	ctx.health_damage = health_damage
	ctx.was_lethal = (tgt.health <= 0)
	
	if ctx.was_lethal:
		tgt.alive = false
		# If you keep corpses in units but remove from order:
		state.remove_unit(ctx.target_id)
	
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
	
	# Optional: reactive statuses (EVENT_BASED) after application
	# _emit_damage_event(ctx, "applied")
	
	return ctx.amount

func resolve_death(combat_id: int, reason := "") -> void:
	if state == null or combat_id <= 0:
		return
	var u := state.get_unit(combat_id)
	if u == null:
		return
	
	u.alive = false
	
	var g := u.team
	if g != -1:
		state.groups[g].remove(combat_id)
	var after_order_ids = PackedInt32Array(state.groups[g].order)
	if writer != null:
		writer.emit_death(combat_id, after_order_ids, String(reason))


func apply_status(ctx: StatusContext) -> void:
	if ctx == null or state == null:
		return
	if ctx.target_id <= 0:
		return
	var u := state.get_unit(ctx.target_id)
	if u == null or !u.is_alive():
		return
	if ctx.status_id == &"":
		return
	
	# Default intensity policy (so callers can omit it)
	if int(ctx.intensity) == 0:
		ctx.intensity = 1
	
	u.statuses.add_or_reapply(ctx.status_id, ctx.intensity, ctx.duration)
	ctx.applied = true
	
	if writer != null:
		writer.emit_status_applied(int(ctx.source_id), int(ctx.target_id), ctx.status_id, int(ctx.intensity), int(ctx.duration))
	
	_rebuild_modifier_cache_for(ctx.target_id)
	_on_status_changed(ctx.target_id)


func remove_status(ctx: RemoveStatusContext) -> void:
	if ctx == null or state == null:
		return
	if ctx.target_id <= 0:
		return
	var u := state.get_unit(ctx.target_id)
	if u == null:
		return
	if ctx.status_id == &"":
		return
	
	var intensity := maxi(int(ctx.intensity if ("intensity" in ctx) else 1), 1)
	
	if ctx.remove_all_intensity:
		u.statuses.remove(ctx.status_id, true)
	else:
		u.statuses.remove(ctx.status_id, false, intensity)
	
	if writer != null:
		writer.emit_status_removed(int(ctx.source_id), int(ctx.target_id), ctx.status_id, intensity, bool(ctx.remove_all_intensity))
	
	_rebuild_modifier_cache_for(ctx.target_id)
	_on_status_changed(ctx.target_id)

func _on_status_changed(cid: int) -> void:
	plan_intent(cid)


func spawn_from_data(combatant_data: CombatantData, group_index: int, insert_index: int = -1, is_player := false) -> int:
	if combatant_data == null or state == null:
		return 0
	
	var id := state.alloc_id()
	if is_player:
		state.groups[FRIENDLY].player_id = id
	var u := CombatantState.new()
	u.id = id
	u.rng = RNG.new(RNGUtil.mix_seed(state.battle_seed, u.id))
	u.combatant_data = combatant_data
	u.init_from_combatant_data(combatant_data)
	
	if combatant_data.resource_path != "":
		u.data_proto_path = String(combatant_data.resource_path)
	
	var g := clampi(group_index, 0, 1)
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
		}
		var after_order_ids = PackedInt32Array(state.groups[g].order)
		writer.emit_spawned(id, g, int(insert_index), after_order_ids, proto, spec)
	
	return id

func summon(ctx: SummonContext) -> void:
	if ctx == null or state == null:
		return
	if ctx.summon_data == null:
		push_warning("SimBattleAPI.summon: missing summon_data")
		return
	
	var id := state.alloc_id()
	ctx.summon_data.combat_id = id
	
	var u := CombatantState.new()
	u.id = id
	u.rng = RNG.new(RNGUtil.mix_seed(state.battle_seed, u.id))
	u.combatant_data = ctx.summon_data
	u.init_from_combatant_data(ctx.summon_data)
	if ctx.summon_data.resource_path != "":
		u.data_proto_path = String(ctx.summon_data.resource_path)
	
	var g := clampi(ctx.group_index, 0, 1)
	state.add_unit(u, g, int(ctx.insert_index))
	var proto := String(u.data_proto_path)
	var spec := {}
	if ctx.summon_data != null:
		spec = {
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
		}
	var after_order_ids = PackedInt32Array(state.groups[g].order)
	if writer != null:
		writer.emit_summoned(id, g, int(ctx.insert_index), after_order_ids, proto, spec)
	
	ctx.summoned_id = id
	ctx.summoned_fighter = null # headless
	#print("[SIM][SUMMON] new_id=%d group=%d idx=%d proto=%s" % [id, g, int(ctx.insert_index), String(u.data_proto_path)])
	if on_summoned.is_valid():
		on_summoned.call(id, g)
	plan_intent(id)

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
	ai_ctx.battle_scene = null
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
	if state == null or ctx == null:
		return

	var tid := int(ctx.target_id)
	var u: CombatantState = state.get_unit(tid)
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	# Update AI memory fields similar to LIVE (optional but helpful for parity)
	if u.ai_state == null:
		u.ai_state = {}
	u.ai_state[ActionPlanner.DMG_SINCE_LAST_TURN] = int(u.ai_state.get(ActionPlanner.DMG_SINCE_LAST_TURN, 0)) + int(ctx.health_damage)

	# If not acting, let it re-evaluate conditions
	# Later: redo this so damage dirties the state
	plan_intent(tid)

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

func plan_intent(cid: int) -> void:
	var u: CombatantState = state.get_unit(int(cid))
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null:
		return
	if u.combatant_data.ai == null:
		return

	ActionPlanner._ensure_ai_state_initialized(u)
	u.ai_state[ActionPlanner.FIRST_INTENTS_READY] = true

	if bool(u.ai_state.get(ActionPlanner.IS_ACTING, false)):
		return

	var ctx_ai := NPCAIContext.new()
	ctx_ai.api = self
	ctx_ai.cid = int(cid)
	ctx_ai.combatant_state = u
	ctx_ai.combatant_data = u.combatant_data
	ctx_ai.state = u.ai_state
	ctx_ai.rng = u.rng
	ctx_ai.params = {}
	ctx_ai.forecast = false

	ActionPlanner.ensure_valid_plan_sim(u.combatant_data.ai, ctx_ai, true)

func plan_intents() -> void:
	for cid in state.units.keys():
		plan_intent(cid)
	

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
