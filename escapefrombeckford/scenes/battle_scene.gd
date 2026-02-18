# battle_scene.gd

class_name BattleScene extends Node2D

@onready var groups: Array[BattleGroup] = [$BattleGroupFriendly, $BattleGroupEnemy]
@onready var target_arrow: Sprite2D = $TargetArrow
@onready var runner: BattleResolutionRunner = $BattleResolutionRunner

var deck: Deck : set = _set_deck
var run: Run : set = _set_run
var _next_combat_id: int = 1
var player: Player
var battle_seed: int
var run_seed: int
var static_mods: BattleStaticModifiers

var api: LiveBattleAPI

func _ready() -> void:
	for group : BattleGroup in groups:
		group.battle_scene = self

func _set_run(new_run: Run) -> void:
	run = new_run
	if !is_node_ready():
		await ready
	for group: BattleGroup in groups:
		group.run = run

func _set_deck(_deck: Deck) -> void:
	deck = _deck
	for group: BattleGroup in groups:
		group.deck = deck

func get_group_by_index(index: int) -> BattleGroup:
	return groups[index]

func get_combatant_by_id(combat_id: int, allow_dead: bool = false) -> Fighter:
	for group: BattleGroup in groups:
		for fighter: Fighter in group.get_combatants(allow_dead):
			if fighter.combat_id == combat_id and is_instance_valid(fighter):
				return fighter
	return null

func alloc_combat_id() -> int:
	var id := _next_combat_id
	_next_combat_id += 1
	return id

func friendly_group_turn_start() -> void:
	print("battle_scene.gd  called but is unhooked")
	#for group: BattleGroup in groups:
		#if group is BattleGroupFriendly:
			#group.my_turn_start()
		#elif group is BattleGroupEnemy:
			#group.opposing_turn_start()

func friendly_group_turn_end() -> void:
	print("battle_scene.gd  called but is unhooked")
	#for group: BattleGroup in groups:
		#if group is BattleGroupFriendly:
			#group.my_turn_end()
		#elif group is BattleGroupEnemy:
			#group.opposing_turn_end()


func enemy_group_turn_start() -> void:
	print("battle_scene.gd  called but is unhooked")
	#for group: BattleGroup in groups:
		#if group is BattleGroupFriendly:
			#group.opposing_turn_start()
		#elif group is BattleGroupEnemy:
			#group.my_turn_start()

func enemy_group_turn_end() -> void:
	print("battle_scene.gd  called but is unhooked")
	#for group: BattleGroup in groups:
		#if group is BattleGroupFriendly:
			#group.opposing_turn_end()
		#elif group is BattleGroupEnemy:
			#group.my_turn_end()

func get_index_of_parent_group(fighter: Fighter) -> int:
	for i in range(groups.size()):
		if groups[i].get_combatants().has(fighter):
			return i
	return -1

func get_group_index_for(group: Node) -> int:
	for i in range(groups.size()):
		if groups[i] == group:
			return i
	return -1


func add_combatant(fighter: Fighter, group: int, rank: int):
	fighter.battle_scene = self
	var combat_id := alloc_combat_id()
	fighter.combat_id = combat_id
	if fighter.combatant_data:
		fighter.combatant_data.combat_id = combat_id
	print("alloc combat_id=", combat_id, " for ", fighter.name)
	groups[group].add_combatant(fighter, rank)

func remove_combatant(fighter: Fighter):
	for group in groups:
		group.remove_combatant(fighter)

func kill_enemies() -> void:
	if !api:
		push_warning("BattleScene.kill_enemies(): no api")
		return

	# Snapshot combat_ids first (runner will handle dedupe + ordering)
	var ids: Array[int] = []
	for f: Fighter in groups[1].get_combatants(true): # allow_dead=true
		if f and is_instance_valid(f):
			# Skip already-dead data if you want; optional:
			# if !f.is_alive(): continue
			if f.combat_id > 0:
				ids.append(f.combat_id)

	for cid in ids:
		api.resolve_death(cid, "debug_kill_enemies")


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
	player = new_player

## Returns positional displacement of `fighter` relative to the Player.
##  0  = the player
##  1  = one position behind the player
## -1  = one position in front of the player
## -2  = two positions in front of the player
## etc.
##
## If the fighter is not in the same group as the Player,
## returns 0 and emits a warning.
func get_player_pos_delta(fighter: Fighter) -> int:
	if !fighter:
		push_warning("get_player_pos_delta: fighter is null")
		return 0

	var player := get_player()
	if !player:
		push_warning("get_player_pos_delta: no player found in battle")
		return 0

	var player_group := player.get_parent()
	var fighter_group := fighter.get_parent()

	if fighter_group != player_group:
		push_warning("fighter has no player in group")
		return 0

	var fighters: Array[Fighter] = player_group.get_combatants()

	var player_index := fighters.find(player)
	var fighter_index := fighters.find(fighter)

	if player_index == -1 or fighter_index == -1:
		push_warning("get_player_pos_delta: fighter or player not found in group combatants")
		return 0

	# Displacement: behind player = positive, ahead = negative
	return fighter_index - player_index


func get_battle_groups() -> Array[BattleGroup]:
	var battle_groups: Array[BattleGroup] = []
	for child_group in get_children():
		if child_group is BattleGroup:
			battle_groups.push_back(child_group)
	return battle_groups

func get_front_combatant(battle_group_index: int) -> Fighter:
	var child_groups = get_battle_groups()
	for child_combatant: Fighter in child_groups[battle_group_index].get_combatants():
		if child_combatant.is_alive():
			return child_combatant
	return null

func get_other_battle_group(idx: int) -> BattleGroup:
	if groups.size() != 2:
		push_error("Array must contain exactly 2 elements")
		return null
	if idx < 0 or idx > 1:
		push_error("Index must be 0 or 1")
		return null
	return groups[1 - idx]

func get_summon_slot_position(battle_group_index: int, slot_index: int) -> Vector2:
		return groups[battle_group_index].get_summon_slot_position(slot_index)

func execute_move_ctx(ctx: MoveContext) -> void:
	if !ctx or !ctx.actor:
		return

	var group := get_group_for_actor(ctx.actor)
	if !group:
		push_warning("BattleScene.execute_move_ctx(): actor not found in any BattleGroup")
		return

	group.execute_move_ctx(ctx)


func execute_move(effect: MoveEffect) -> void:
	var group := get_group_for_actor(effect.actor)
	if not group:
		push_warning(
		"BattleScene.execute_move(): Actor %s not found in any BattleGroup"
		% effect.actor.name
		)
		return
	group.execute_move(effect)


func get_group_for_actor(actor: Fighter) -> BattleGroup:
	if not actor:
		return null
	var parent := actor.get_parent()
	for group: BattleGroup in groups:
		if group == parent:
			return group
	return null

# battle_scene.gd
func get_turn_order_snapshot() -> TurnOrderSnapshot:
	var snap := TurnOrderSnapshot.new()
	
	# Defensive
	if !groups or groups.size() < 2:
		push_warning("BattleScene.get_turn_order_snapshot(): groups missing")
		return snap
	
	var friendly_group := groups[0]
	var enemy_group := groups[1]
	if !friendly_group or !enemy_group:
		push_warning("BattleScene.get_turn_order_snapshot(): group null")
		return snap
	
	var friendlies: Array[Fighter] = friendly_group.get_combatants()
	var enemies: Array[Fighter] = enemy_group.get_combatants()
	
	# Friendly lane (front->back in group order)
	for i in range(friendlies.size()):
		var f := friendlies[i]
		if !f:
			continue
		if f is Player:
			snap.player_index = snap.friendly.size() # index in the filtered list
		snap.friendly.append(_fighter_to_turn_entry(f))
	
	# Enemy lane (front->back in *their* group order)
	for f in enemies:
		if !f:
			continue
		snap.enemy.append(_fighter_to_turn_entry(f))
	
	return snap


func _fighter_to_turn_entry(f: Fighter) -> Dictionary:
	# Choose a consistent "spark contact point"
	var h := 200.0
	if f.combatant_data:
		h = float(f.combatant_data.height)
	
	var contact := f.global_position + Vector2(0, -h * 0.6)
	
	return {
		"pos": contact,
		"id": f.get_instance_id(),
		"is_player": f is Player,
		"is_summon": f is SummonedAlly,
		"is_enemy": f is Enemy,
	}


##attack effect target pipeline

#func get_targets_for_attack_sequence(ai_ctx: NPCAIContext) -> Array[Fighter]:
	#var atk_ctx := AttackTargetContext.new()
	#atk_ctx.source = ai_ctx.combatant
	#atk_ctx.params = ai_ctx.params
	#atk_ctx.base_targets = _get_base_targets_for_attack_sequence(
		#atk_ctx.source,
		#atk_ctx.params
	#)
	#atk_ctx.base_targets = atk_ctx.base_targets.filter(func(t): return t != null)
	#atk_ctx.final_targets = atk_ctx.base_targets.duplicate()
	#atk_ctx.is_single_target_intent = _get_if_single_target_sequence(atk_ctx.params)
	#_apply_target_modifiers(atk_ctx)
	#return atk_ctx.final_targets

#func _get_base_targets_for_attack_sequence(
	#source: Fighter,
	#params: Dictionary
#) -> Array[Fighter]:
	#var target_type : String = params.get(
		#NPCKeys.TARGET_TYPE,
		#NPCAttackSequence.TARGET_STANDARD
	#)
	#match target_type:
		#NPCAttackSequence.TARGET_STANDARD:
			#return [get_front_enemy_of(source)]
		#NPCAttackSequence.TARGET_OPPONENTS:
			#return get_enemies_of(source)
		#NPCAttackSequence.TARGET_ALL:
			#return get_all_combatants()
	#return []

#func _get_if_single_target_sequence(params: Dictionary) -> bool:
	#var target_type : String = params.get(
		#NPCKeys.TARGET_TYPE,
		#NPCAttackSequence.TARGET_STANDARD
	#)
	#match target_type:
		#NPCAttackSequence.TARGET_STANDARD:
			#return true
		#NPCAttackSequence.TARGET_OPPONENTS:
			#return false
		#NPCAttackSequence.TARGET_ALL:
			#return false
	#return false

#func _apply_target_modifiers(ctx: AttackTargetContext) -> void:
	#for fighter in get_all_combatants():
		#fighter.modify_target(ctx)

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

		for token in source.status_system.get_modifier_tokens():
			if token.scope == ModifierToken.Scope.GLOBAL and token.tags.has(Aura.AURA_SECONDARY_FLAG):
				push_error("Aura token must not be GLOBAL: %s" % token.source_id)
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
						if token.tags.has(Aura.AURA_ALLIES):
							# Applies to source + allies (exclude self if wanted)
							if same_group:
								tokens.append(token)
						elif token.tags.has(Aura.AURA_ENEMIES):
							# Applies to enemies of the source
							if !same_group:
								tokens.append(token)
					else:
						# Non-aura TARGET token: only for its explicit owner
						if token.owner == fighter:
							tokens.append(token)
	return tokens

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
			#fighter._on_modifier_changed()


# battle_scene.gd
func build_turn_order_path() -> TurnOrderPath:
	var path := TurnOrderPath.new()

	# Defensive: need 2 groups (0=friendly, 1=enemy)
	if groups.size() < 2:
		return path

	var friendly_group: Node = groups[0]
	var enemy_group: Node = groups[1]

	if !friendly_group or !enemy_group:
		return path
	if !friendly_group.has_method("get_combatants") or !enemy_group.has_method("get_combatants"):
		return path

	var friendlies: Array[Fighter] = friendly_group.get_combatants()
	var enemies: Array[Fighter] = enemy_group.get_combatants()

	if friendlies.is_empty():
		return path

	# ----------------------------
	# Find player + index
	# ----------------------------
	var player_fighter: Fighter = null
	for f in friendlies:
		if f is Player:
			player_fighter = f
			break
	if player_fighter == null:
		# Fallback: treat "front friendly" as the anchor
		player_fighter = friendlies[0]

	var player_idx := friendlies.find(player_fighter)
	if player_idx < 0:
		player_idx = 0

	path.player_pos = player_fighter.global_position

	# ----------------------------
	# Friendlies behind player (moving left): indices player_idx+1..end
	# ----------------------------
	path.behind_friendlies = []
	for i in range(player_idx + 1, friendlies.size()):
		var f := friendlies[i]
		if f and f.is_alive():
			path.behind_friendlies.append(f.global_position)

	# ----------------------------
	# Enemies front-to-back (moving right): indices 0..end
	# ----------------------------
	path.enemies_front_to_back = []
	for e in enemies:
		if e and e.is_alive():
			path.enemies_front_to_back.append(e.global_position)

	# ----------------------------
	# Friendlies in front of player (moving left back toward player):
	# indices 0..player_idx-1 (frontmost first)
	# ----------------------------
	path.in_front_friendlies = []
	for i in range(0, player_idx):
		var f := friendlies[i]
		if f and f.is_alive():
			path.in_front_friendlies.append(f.global_position)

	# ----------------------------
	# Middle position = mean(front friendly, front enemy)
	# (front is index 0 in each group's combatant order)
	# ----------------------------
	var front_friendly_pos := friendlies[0].global_position
	var front_enemy_pos := front_friendly_pos

	if !enemies.is_empty():
		front_enemy_pos = enemies[0].global_position

	path.middle_pos = (front_friendly_pos + front_enemy_pos) * 0.5

	return path


func build_static_modifiers_from_arcana() -> void:
	static_mods = BattleStaticModifiers.new()

	for f: Fighter in get_all_combatants():
		if !f:
			continue

		# Ask arcana layer only
		var arcana_tokens := run.arcana_system.get_modifier_tokens_for(f)
		var id_tokens: Array[ModifierToken] = []
		for t in arcana_tokens:
			id_tokens.append(ModifierTokenUtil.to_id_token(t))

		static_mods.set_tokens_for_target(f.combat_id, id_tokens)
