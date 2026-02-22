# sim_battle_api.gd

class_name SimBattleAPI extends BattleAPI

var state: BattleState

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

func has_status(combat_id: int, status_id: StringName) -> bool:
	var u := state.get_unit(combat_id)
	if u == null or !u.is_alive():
		return false
	return u.statuses.has(status_id)


func find_marked_ranged_redirect_target(attacker_id: int) -> int:
	for id in get_enemies_of(attacker_id):
		if has_status(id, &"marked"):
			return id
	return 0


func get_targets_for_attack_sequence(ai_ctx) -> Array:
	var attacker_id := 0
	if ai_ctx == null:
		return []

	if ai_ctx.combatant_data:
		attacker_id = int(ai_ctx.combatant_data.combat_id)
	elif ai_ctx.combatant:
		attacker_id = int(ai_ctx.combatant.combat_id)

	if attacker_id <= 0:
		return []

	# AttackTargeting should be API-driven already.
	return AttackTargeting.get_target_ids(self, attacker_id, ai_ctx.params)


# --------------------------
# Core verbs (SYNC)
# --------------------------

func resolve_damage(ctx: DamageContext) -> void:
	# In sim, "resolve_damage" is immediate by default.
	resolve_damage_immediate(ctx)

func resolve_damage_immediate(ctx: DamageContext) -> void:
	if ctx == null or state == null:
		return

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
	# remove from ordering (corpse can remain addressable in units dict)
	var g := u.team
	if g != -1:
		state.groups[g].remove(combat_id)
	# optional: battle-level hook
	# state.on_death(combat_id, reason)


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

	# Headless status application: store stacks/duration only.
	# Any “on apply” hooks should be centralized elsewhere later.
	u.statuses.add_or_reapply(ctx.status_id, ctx.intensity, ctx.duration)
	ctx.applied = true

	# When statuses change, rebuild modifier caches if you use them.
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

	if ctx.remove_all_stacks:
		u.statuses.remove(ctx.status_id, true)
	else:
		u.statuses.remove(ctx.status_id, false, 1)

	_rebuild_modifier_cache_for(ctx.target_id)


func summon(ctx: SummonContext) -> void:
	# Headless summon should only mutate state + ordering.
	# Creating CombatantState from a proto is a host/catalog concern.
	if ctx == null or state == null:
		return

	# Expect ctx already has: summoned_id and a prebuilt CombatantState (ideal),
	# OR ctx.summon_data and host can translate.
	# Here: support "ctx.summoned_state" as the clean path.
	if !ctx.has_meta("summoned_state"):
		push_warning("SimBattleAPI.summon: ctx missing summoned_state")
		return

	var u: CombatantState = ctx.get_meta("summoned_state")
	if u == null:
		return

	var g := clampi(ctx.group_index, 0, 1)
	var idx := ctx.insert_index
	state.add_unit(u, g, idx)


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
		MoveContext.MoveType.TRAVERSE_PLAYER:
			# This is a policy decision. Implement once you have "player_id" stored in GroupState.
			pass
		_:
			pass

	# Snapshot after
	ctx.after_order_ids = PackedInt32Array(state.groups[g].order)


func resolve_attack_now(ctx: AttackNowContext) -> void:
	# In sim: typically build a NPCAIContext and run NPCAttackSequence synchronously.
	# This is optional right now; can stay stubbed until AI is wired headlessly.
	pass


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

func on_damage_applied(ctx: DamageContext) -> void:
	if state == null or ctx == null:
		return
	# Headless hooks go here later:
	# - status procs on damage
	# - AI memory
	# - “on hit” triggers
	# Keep it empty until you formalize procs.
	pass


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
