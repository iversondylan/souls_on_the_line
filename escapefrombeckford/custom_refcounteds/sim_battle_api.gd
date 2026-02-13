# sim_battle_api.gd
class_name SimBattleAPI extends BattleAPI

var battle: SimBattle


# The only missing piece in my sim right now is a stable group order / rank system. 
# I already build TurnOrderSnapshot and TurnOrderPath in live; 
# sim needs the numeric equivalent:
# group_order[0] = [front..back ids]
# group_order[1] = [front..back ids]
# That’s enough for attacks, moves, player-delta, “front enemy”, etc.


func _init(_battle: SimBattle) -> void:
	battle = _battle

func is_alive(combat_id: int) -> bool:
	var f := battle.get_fighter(combat_id)
	return f != null and f.is_alive()

func get_group(combat_id: int) -> int:
	var f := battle.get_fighter(combat_id)
	return f.group if f else -1

func get_team(combat_id: int) -> int:
	var f := battle.get_fighter(combat_id)
	return f.team if f else -1

func get_opposing_group(group_index: int) -> int:
	return 1 - clampi(group_index, 0, 1)

func get_combatants_in_group(group_index: int, allow_dead := false) -> Array[int]:
	var ids: Array[int] = []
	# you need a stable ordering list in SimBattle:
	# e.g., battle.group_order[0] / battle.group_order[1]
	for id in battle.get_group_order(group_index): # front->back ids
		if allow_dead or is_alive(id):
			ids.append(id)
	return ids

func get_front_combatant_id(group_index: int) -> int:
	for id in get_combatants_in_group(group_index, false):
		return id
	return 0

func get_enemies_of(combat_id: int) -> Array[int]:
	var g := get_group(combat_id)
	if g == -1:
		return []
	return get_combatants_in_group(get_opposing_group(g), false)

func get_rank_in_group(combat_id: int) -> int:
	return battle.get_rank_in_group(combat_id) # index in group_order

func get_targets_for_attack_sequence(ai_ctx) -> Array[int]:
	var attacker_id := 0
	if ai_ctx.combatant_data:
		attacker_id = ai_ctx.combatant_data.combat_id
	elif ai_ctx.combatant:
		attacker_id = ai_ctx.combatant.combat_id
	if attacker_id <= 0:
		return []
	return AttackTargeting.get_target_ids(self, attacker_id, ai_ctx.params)

func resolve_damage(ctx: DamageContext) -> void:
	# No runner; resolve immediately
	if !ctx:
		return
	# ensure ids exist
	if ctx.target_id == 0 and ctx.target:
		ctx.target_id = ctx.target.combat_id
	if ctx.source_id == 0 and ctx.source:
		ctx.source_id = ctx.source.combat_id

	# SimDamageResolver path
	DamageResolver.resolve(self, ctx)


func modify_damage_amount(ctx: DamageContext, base: int) -> int:
	var amount := base
	var src_id := ctx.source_id
	var tgt_id := ctx.target_id

	amount = battle.get_modified_value(src_id, amount, ctx.deal_modifier_type)
	amount = battle.get_modified_value(tgt_id, amount, ctx.take_modifier_type)
	return amount

func apply_damage_amount(ctx: DamageContext, amount: int) -> void:
	var f := battle.get_fighter(ctx.target_id)
	if !f or !f.is_alive():
		return

	# Whatever your sim stats object is, it should mirror:
	# - pre_armor
	# - actual health loss
	# - lethal
	var pre_armor : int = f.stats.armor
	var health_loss : int = f.stats.take_damage(amount) # or apply_damage_amount(amount) but return only numbers

	ctx.health_damage = health_loss
	ctx.armor_damage = maxi(mini(amount, pre_armor), 0)
	ctx.was_lethal = !f.stats.is_alive() # or f.is_alive after stats update


func on_damage_applied(ctx: DamageContext) -> void:
	# Sim hooks: statuses that react to damage, AI state updates, etc.
	# You can mirror StatusGrid.on_damage_taken semantics here later.
	battle.on_damage_taken(ctx)

func resolve_death(combat_id: int, reason := "") -> void:
	var f := battle.get_fighter(combat_id)
	if f:
		f.alive = false

func has_status(combat_id: int, status_id: StringName) -> bool:
	var f := battle.get_fighter(combat_id)
	if !f or !f.is_alive():
		return false
	return f.statuses.has_status(String(status_id))

func find_marked_ranged_redirect_target(attacker_id: int) -> int:
	for id in get_enemies_of(attacker_id):
		if has_status(id, &"marked"):
			return id
	return 0
