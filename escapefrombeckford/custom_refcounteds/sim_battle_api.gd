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

func resolve_damage(ctx: DamageContext) -> void:
	resolve_damage_immediate(ctx)

func resolve_attack(ctx: NPCAIContext) -> bool:
	return SimAttackRunner.run(self, ctx)

func resolve_damage_immediate(ctx: DamageContext) -> void:
	if ctx == null or state == null:
		return
	print("sim_battle_api.gd resolve_damage_immediate() src=%d tgt=%d base=%d amt=%d alive=%s" % [
		int(ctx.source_id),
		int(ctx.target_id),
		int(ctx.base_amount),
		int(ctx.amount),
		str(state.is_alive(int(ctx.target_id))) if state and int(ctx.target_id) > 0 else "?"
	])
	# ensure ids
	if ctx.target_id == 0 and ctx.target:
		ctx.target_id = int(ctx.target.combat_id)
	if ctx.source_id == 0 and ctx.source:
		ctx.source_id = int(ctx.source.combat_id)

	# bail if invalid / dead
	if ctx.target_id <= 0 or !state.is_alive(ctx.target_id):
		return

	# Central resolver should call back into:
	# - modify_damage_amount()
	# - apply_damage_amount()
	# - on_damage_applied()
	DamageResolver.resolve(self, ctx)

	if ctx.was_lethal:
		resolve_death(ctx.target_id, "damage")

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

	if writer != null:
		writer.emit_death(combat_id, String(reason))


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

	var stacks_delta := maxi(int(ctx.stacks_delta if ("stacks_delta" in ctx) else 1), 1)

	if ctx.remove_all_stacks:
		u.statuses.remove(ctx.status_id, true)
	else:
		u.statuses.remove(ctx.status_id, false, stacks_delta)

	if writer != null:
		writer.emit_status_removed(int(ctx.source_id), int(ctx.target_id), ctx.status_id, stacks_delta, bool(ctx.remove_all_stacks))

	_rebuild_modifier_cache_for(ctx.target_id)
	_rebuild_modifier_cache_for(ctx.target_id)


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
			&"name": String(ctx.summon_data.name),
			&"max_hp": int(ctx.summon_data.max_health),
			&"hp": int(ctx.summon_data.health),
			&"armor": int(ctx.summon_data.armor),
			&"max_mana_blue": int(ctx.summon_data.max_mana_blue),
			&"max_mana_green": int(ctx.summon_data.max_mana_green),
			&"max_mana_red": int(ctx.summon_data.max_mana_red),
			&"proto_path": String(ctx.summon_data.resource_path),
		}

	if writer != null:
		writer.emit_summoned(id, g, int(ctx.insert_index), proto, spec)
	
	ctx.summoned_id = id
	ctx.summoned_fighter = null # headless
	print("[SIM][SUMMON] new_id=%d group=%d idx=%d proto=%s" % [id, g, int(ctx.insert_index), String(u.data_proto_path)])
	if on_summoned.is_valid():
		on_summoned.call(id, g)

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
		writer.scope_begin(Keys.SCOPE_MOVE, "actor=%d" % int(ctx.actor_id), int(ctx.actor_id))
		var extra := {}
		if int(ctx.target_id) > 0:
			extra[Keys.TARGET_ID] = int(ctx.target_id)
		if int(ctx.index) >= 0:
			extra[Keys.TO_INDEX] = int(ctx.index)
		writer.emit_moved(int(ctx.actor_id), int(ctx.move_type), ctx.before_order_ids, ctx.after_order_ids, extra)
		writer.scope_end()

#func resolve_move(ctx: MoveContext) -> void:
	#if ctx == null or state == null:
		#return
	#if ctx.actor_id <= 0:
		#return
	#var u := state.get_unit(ctx.actor_id)
	#if u == null or !u.is_alive():
		#return
#
	#var g := u.team
	#if g < 0:
		#return
#
	## Snapshot before
	#ctx.before_order_ids = PackedInt32Array(state.groups[g].order)
#
	#match ctx.move_type:
		#MoveContext.MoveType.MOVE_TO_FRONT:
			#_move_id_to_index(g, ctx.actor_id, 0)
		#MoveContext.MoveType.MOVE_TO_BACK:
			#_move_id_to_index(g, ctx.actor_id, state.groups[g].order.size() - 1)
		#MoveContext.MoveType.INSERT_AT_INDEX:
			#_move_id_to_index(g, ctx.actor_id, ctx.index)
		#MoveContext.MoveType.SWAP_WITH_TARGET:
			#if ctx.target_id > 0:
				#_swap_ids(g, ctx.actor_id, ctx.target_id)
		#MoveContext.MoveType.TRAVERSE_PLAYER:
			## This is a policy decision. Implement once you have "player_id" stored in GroupState.
			#pass
		#_:
			#pass
#
	## Snapshot after
	#ctx.after_order_ids = PackedInt32Array(state.groups[g].order)


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

func apply_damage_amount(ctx: DamageContext, amount: int) -> void:
	if state == null or ctx == null:
		return
	var tgt := state.get_unit(ctx.target_id)
	if tgt == null or !tgt.is_alive():
		return

	var pre_armor := tgt.armor

	# Armor-first; adjust to match your live CombatantData.take_damage semantics.
	var remaining := amount
	var armor_loss := mini(pre_armor, remaining)
	tgt.armor = pre_armor - armor_loss
	remaining -= armor_loss

	var pre_hp := tgt.health
	tgt.health = maxi(pre_hp - remaining, 0)

	ctx.armor_damage = armor_loss
	ctx.health_damage = pre_hp - tgt.health
	ctx.was_lethal = (tgt.health <= 0)
	

	if writer != null:
		writer.emit_damage_applied(
			int(ctx.source_id),
			int(ctx.target_id),
			int(ctx.base_amount),
			int(amount),
			int(ctx.armor_damage),
			int(ctx.health_damage),
			bool(ctx.was_lethal)
		)

func on_damage_applied(ctx: DamageContext) -> void:
	if state == null or ctx == null:
		return
	# Headless hooks go here later:
	# - status procs on damage
	# - AI memory
	# - “on hit” triggers
	# Keep it empty until you formalize procs.
	pass

func on_card_played(ctx: CardActionContextSim) -> void:
	if ctx == null or ctx.card_data == null:
		return
	if writer == null:
		return
	
	if ctx.emitted_card_played:
		return
	ctx.emitted_card_played = true
	
	ctx.card_data.ensure_uid()

	writer.scope_begin(Keys.SCOPE_CARD, "uid=%s %s" % [str(ctx.card_data.uid), String(ctx.card_data.name)], int(ctx.source_id))

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
