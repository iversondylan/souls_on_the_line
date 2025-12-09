class_name BattleScene extends Node2D

@onready var groups: Array[BattleGroup] = [$BattleGroupFriendly, $BattleGroupEnemy]
var deck: Deck : set = _set_deck

func _ready() -> void:
	for group : BattleGroup in groups:
		group.battle_scene = self

func _set_deck(_deck: Deck) -> void:
	deck = _deck
	for group: BattleGroup in groups:
		group.deck = deck

func get_index_of_parent_group(fighter: Fighter) -> int:
	for i in range(groups.size()):
		if groups[i].get_combatants().has(fighter):
			return i
	return -1

func add_combatant(fighter: Fighter, group: int, rank: int):
	fighter.battle_scene = self
	groups[group].add_combatant(fighter, rank)

func remove_combatant(fighter: Fighter):
	for group in groups:
		group.remove_combatant(fighter)

func kill_enemies() -> void:
	var fighters := get_enemies()
	for fighter: Fighter in fighters:
		groups[1].combatant_died(fighter)
		

func clear_combatants():
	for group in groups:
		group.clear_combatants()

func combatant_is_there(fighter: Fighter) -> bool:
	var is_it: bool = false
	for group: BattleGroup in groups:
		if group.combatant_is_there(fighter):
			is_it = true
	return is_it

func get_combatants_in_group(group_index: int) -> Array[Fighter]:
	return groups[group_index].get_combatants()

func get_all_combatants() -> Array[Fighter]:
	return groups[0].get_combatants() + groups[1].get_combatants()

func get_n_combatants_in_group(group_index: int) -> int:
	return groups[group_index].get_combatants().size()

func get_n_summoned_allies() -> int:
	return (groups[0] as BattleGroupFriendly).get_n_summoned_allies()

func get_allies_of(fighter: Fighter) -> Array[Fighter]:
	var index := get_index_of_parent_group(fighter)
	var fighters := groups[index].get_combatants()
	fighters.erase(fighter)
	return fighters

func get_enemies_of(fighter: Fighter) -> Array[Fighter]:
	var index := get_index_of_parent_group(fighter)
	return get_other_battle_group(index).get_combatants()

func get_combatants() -> Array[Fighter]:
	var fighters: Array[Fighter] = []
	for child_group in get_children():
		if child_group is BattleGroup:
			for fighter in child_group.get_combatants():
				fighters.push_back(fighter)
	return fighters

func get_summons() -> Array[Fighter]:
	var fighters: Array[Fighter] = []
	for child_group in get_children():
		if child_group is BattleGroup:
			for fighter in child_group.get_combatants():
				if fighter.combatant_data.team == 1:
					fighters.push_back(fighter)
	return fighters

func get_enemies() -> Array[Fighter]:
	var fighters: Array[Fighter]
	for child_group in get_children():
		if child_group is BattleGroupEnemy:
			fighters = child_group.get_combatants()
	return fighters

func get_player() -> Player:
	var player: Player = null
	for child_group in get_children():
		if child_group is BattleGroup:
			for child_combatant in child_group.get_combatants():
				if child_combatant is Player:
					if !player:
						player = child_combatant
					else:
						print("ERROR: MORE THAN ONE PLAYER")
	return player

func set_player(new_player: Player) -> void:
	groups[0].player = new_player

func get_battle_groups() -> Array[BattleGroup]:
	var battle_groups: Array[BattleGroup] = []
	for child_group in get_children():
		if child_group is BattleGroup:
			battle_groups.push_back(child_group)
	return battle_groups

func get_front_combatant(battle_group_index: int) -> Fighter:
	var child_groups = get_battle_groups()
	#var child_combatants: Array[Fighter] = child_groups[battle_group_index].get_combatants()
	#var front_combatant: Fighter = null
	for child_combatant: Fighter in child_groups[battle_group_index].get_combatants():
		if child_combatant.combatant_data.is_alive:
			return child_combatant
	return null

func get_front_or_focus(battle_group_index: int) -> Fighter:
	return groups[battle_group_index].get_front_or_focus()

func get_other_battle_group(idx: int) -> BattleGroup:
	if groups.size() != 2:
		push_error("Array must contain exactly 2 elements")
		return null
	if idx < 0 or idx > 1:
		push_error("Index must be 0 or 1")
		return null
	return groups[1 - idx]

##attack effect target pipeline
func get_targets_for_attack_effect(effect: AttackEffect, source: Fighter) -> Array[Fighter]:
	# 1. Build the context
	var ctx := AttackTargetContext.new()
	ctx.source = source
	ctx.effect = effect
	ctx.base_targets = _get_base_targets(source, effect)
	ctx.base_targets = ctx.base_targets.filter(func(t): return t != null)
	ctx.final_targets = ctx.base_targets.duplicate()
	ctx.is_single_target_intent = _get_if_single_target(effect)
	# 2. Run the modifier pipeline
	_apply_target_modifiers(ctx)

	# 3. Return the result
	return ctx.final_targets

func _apply_target_modifiers(ctx: AttackTargetContext) -> void:
	for fighter in get_all_combatants():
		fighter.modify_target(ctx)
	# later:
	# apply arcana modifiers
	# apply global event modifiers
	# apply battlefield rules

func _get_base_targets(source: Fighter, effect: AttackEffect) -> Array[Fighter]:
	# For now: always front enemy
	match effect.target_type:
		AttackEffect.TargetType.STANDARD:
			return [get_front_enemy_of(source)]
		AttackEffect.TargetType.ALL_OPPONENTS:
			return get_enemies_of(source)
	return []

func _get_if_single_target(effect: AttackEffect) -> bool:
	match effect.target_type:
		AttackEffect.TargetType.STANDARD:
			return true
		AttackEffect.TargetType.ALL_OPPONENTS:
			return false
	return false

func get_front_enemy_of(source: Fighter) -> Fighter:
	var enemies = get_enemy_fighters_of(source)
	if enemies.is_empty():
		return null
	return enemies[0]

func get_enemy_fighters_of(source: Fighter) -> Array[Fighter]:
	if source.get_parent() is BattleGroupFriendly:
		return get_combatants_in_group(1)
	else:
		return get_combatants_in_group(0)

##Numerical Modifier System
func get_modifier_tokens_for(fighter: Fighter) -> Array[ModifierToken]:
	var tokens: Array[ModifierToken] = []

	for combatant in get_all_combatants():
		if !combatant.is_alive():
			continue

		var source: Fighter = combatant
		var same_group := source.battle_group == fighter.battle_group

		for token in source.combatant.status_grid.get_modifier_tokens():
			match token.scope:
				ModifierToken.Scope.GLOBAL:
					# Always applies to everyone
					tokens.append(token)

				ModifierToken.Scope.SELF:
					# Only applies to the source itself
					if source == fighter:
						tokens.append(token)

				ModifierToken.Scope.TARGET:
					# Two cases:
					# 1) Normal “targeted” token (non-aura) — uses token.owner.
					# 2) Aura-style token — routed by allies/enemies tags.
					if token.tags.has(Aura.AURA_SECONDARY_FLAG):
						# Aura-style routing
						if token.tags.has("aura_allies"):
							# Applies to source + allies (you can exclude self if you want)
							if same_group:
								tokens.append(token)
						elif token.tags.has("aura_enemies"):
							# Applies to enemies of the source
							if !same_group:
								tokens.append(token)
					else:
						# Non-aura TARGET token: only for its explicit owner
						if token.owner == fighter:
							tokens.append(token)

	return tokens
	#var tokens: Array[ModifierToken] = []
#
	#for combatant in get_all_combatants():
		#if !combatant.is_alive():
			#continue
		#for token in combatant.combatant.status_grid.get_modifier_tokens():
			#match token.scope:
				#ModifierToken.Scope.GLOBAL:
					#tokens.append(token)
				#ModifierToken.Scope.SELF:
					#if combatant == fighter:
						#tokens.append(token)
				#ModifierToken.Scope.TARGET:
					#if token.owner == fighter:
						#tokens.append(token)
#
	#return tokens

func _passes_aura_rules(source: Fighter, target: Fighter, aura: Aura) -> bool:
	# Always apply to self
	if source == target:
		return true

	match aura.aura_type:
		Aura.AuraType.ALLIES:
			return source.battle_group == target.battle_group

		Aura.AuraType.ENEMIES:
			return source.battle_group != target.battle_group

	return false

func _on_modifier_tokens_changed(mod_type: Modifier.Type) -> void:
	for fighter in get_all_combatants():
		if fighter.is_alive():
			fighter.modifier_system.mark_dirty(mod_type)
