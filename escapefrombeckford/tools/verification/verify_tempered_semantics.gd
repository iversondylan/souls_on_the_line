extends SceneTree

const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CardContext := preload("res://cards/_core/card_context.gd")
const CardData := preload("res://cards/_core/card_data.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const DamageContext := preload("res://battle/contexts/damage_context.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const SimStatusSystem := preload("res://battle/sim/operators/sim_status_system.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")
const StatusContext := preload("res://battle/contexts/status_context.gd")

const ABSORB_ID := &"absorb"
const ONE_OF_EACH := preload("res://character_profiles/Cole/one_of_each_card.tres")
const TEMPERED_ID := &"tempered"
const TEMPERED_SILVERBACK := preload("res://cards/souls/TemperedSilverbackCard/tempered_silverback_card.tres")


func _init() -> void:
	_verify_tempered_uses_fixed_stacks_per_hit()
	_verify_tempered_triggers_on_zero_health_damage()
	_verify_tempered_lethal_hit_keeps_on_card_bonus()
	_verify_one_of_each_card_contains_every_repo_card()
	print("verify_tempered_semantics: ok")
	quit()


func _verify_tempered_uses_fixed_stacks_per_hit() -> void:
	var setup := _make_sim()
	var sim := setup.get("sim") as Sim
	var ctx := _play_card(sim, TEMPERED_SILVERBACK)
	var summoned_id := int(ctx.summoned_ids[0])
	var summoned := sim.api.state.get_unit(summoned_id)

	assert(_status_stacks(sim, summoned_id, TEMPERED_ID) == 2, "Tempered Silverback should summon with Tempered 2.")
	assert(int(summoned.max_health) == 6, "Tempered Silverback should start at 6 max health.")

	_apply_direct_damage(sim, int(setup.get("enemy_id", 0)), summoned_id, 1)
	assert(_status_stacks(sim, summoned_id, TEMPERED_ID) == 2, "Tempered stacks should remain fixed after the first hit.")
	assert(int(summoned.max_health) == 8, "The first hit should increase max health by 2.")
	assert(int(sim.api.get_summon_card_max_health_bonus(String(ctx.card_data.uid))) == 2, "The first hit should persist +2 max health onto the bound card.")

	_apply_direct_damage(sim, int(setup.get("enemy_id", 0)), summoned_id, 1)
	assert(_status_stacks(sim, summoned_id, TEMPERED_ID) == 2, "Tempered stacks should remain fixed after repeated hits.")
	assert(int(summoned.max_health) == 10, "The second hit should increase max health by another 2.")
	assert(int(sim.api.get_summon_card_max_health_bonus(String(ctx.card_data.uid))) == 4, "The second hit should accumulate another +2 on-card.")


func _verify_tempered_triggers_on_zero_health_damage() -> void:
	var setup := _make_sim()
	var sim := setup.get("sim") as Sim
	var ctx := _play_card(sim, TEMPERED_SILVERBACK)
	var summoned_id := int(ctx.summoned_ids[0])
	var summoned := sim.api.state.get_unit(summoned_id)

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(sim.api.get_player_id())
	status_ctx.target_id = summoned_id
	status_ctx.status_id = ABSORB_ID
	status_ctx.stacks = 1
	status_ctx.reason = "verify_tempered_absorb"
	sim.api.apply_status(status_ctx)

	_apply_direct_damage(sim, int(setup.get("enemy_id", 0)), summoned_id, 5)
	assert(int(summoned.max_health) == 8, "Tempered should trigger even when the hit deals 0 health damage.")
	assert(int(summoned.health) == 6, "A fully absorbed hit should not reduce current health.")
	assert(_status_stacks(sim, summoned_id, TEMPERED_ID) == 2, "Zero-damage hits should not change Tempered stacks.")


func _verify_tempered_lethal_hit_keeps_on_card_bonus() -> void:
	var setup := _make_sim()
	var sim := setup.get("sim") as Sim
	var ctx := _play_card(sim, TEMPERED_SILVERBACK)
	var summoned_id := int(ctx.summoned_ids[0])
	var summoned := sim.api.state.get_unit(summoned_id)

	summoned.health = 1
	_apply_direct_damage(sim, int(setup.get("enemy_id", 0)), summoned_id, 99)

	assert(!sim.api.is_alive(summoned_id), "The lethal verification hit should kill Tempered Silverback.")
	assert(int(sim.api.get_summon_card_max_health_bonus(String(ctx.card_data.uid))) == 2, "A lethal hit should still persist Tempered's max-health bonus on-card.")


func _verify_one_of_each_card_contains_every_repo_card() -> void:
	assert(ONE_OF_EACH != null, "one_of_each_card.tres should load.")
	assert(int(ONE_OF_EACH.cards.size()) == 61, "one_of_each_card.tres should contain one copy of every repo card.")

	var expected_paths := _collect_repo_card_paths("res://cards")
	var actual_paths := {}
	for card in ONE_OF_EACH.cards:
		assert(card != null, "one_of_each_card.tres should not contain null entries.")
		var path := String(card.resource_path)
		assert(!path.is_empty(), "Cards in one_of_each_card.tres should retain their resource paths.")
		assert(!actual_paths.has(path), "one_of_each_card.tres should not contain duplicate card entries: %s" % path)
		actual_paths[path] = true

	assert(actual_paths.size() == expected_paths.size(), "one_of_each_card.tres should match the repo card count.")
	for path in expected_paths.keys():
		assert(actual_paths.has(path), "one_of_each_card.tres is missing %s." % path)


func _collect_repo_card_paths(dir_path: String) -> Dictionary:
	var found := {}
	_collect_repo_card_paths_recursive(dir_path, found)
	found.erase("res://cards/_core/card_catalog.tres")
	return found


func _collect_repo_card_paths_recursive(dir_path: String, found: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	for subdir in dir.get_directories():
		_collect_repo_card_paths_recursive("%s/%s" % [dir_path, subdir], found)

	for file_name in dir.get_files():
		if !file_name.ends_with(".tres"):
			continue
		var path := "%s/%s" % [dir_path, file_name]
		var resource := load(path)
		if resource is CardData:
			found[path] = true


func _make_sim() -> Dictionary:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(717, 818)
	sim.runtime.sim = sim
	sim.state.resource.max_mana = 99
	sim.state.resource.mana = 99
	sim.api.writer.allow_unscoped_events = true

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	var enemy := _make_unit(sim.state, "Enemy", BattleState.ENEMY, CombatantView.Type.ENEMY, 30, 0)

	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)
	sim.api.writer.set_turn_context(1, BattleState.FRIENDLY, int(player.id))

	return {
		"sim": sim,
		"enemy_id": int(enemy.id),
	}


func _make_unit(
	state: BattleState,
	name: String,
	group_index: int,
	combatant_type: int,
	max_health: int,
	ap: int
) -> CombatantState:
	var unit := CombatantState.new()
	unit.id = state.alloc_id()
	unit.name = name
	unit.type = combatant_type
	unit.mortality = CombatantState.Mortality.MORTAL
	unit.max_health = max_health
	unit.health = max_health
	unit.ap = ap
	unit.alive = true
	state.add_unit(unit, group_index)
	return unit


func _play_card(sim: Sim, proto: CardData) -> CardContext:
	var card := proto.make_runtime_instance()
	var ctx := CardContext.new()
	ctx.api = sim.api
	ctx.runtime = sim.runtime
	ctx.source_id = int(sim.api.get_player_id())
	ctx.card_data = card

	if sim.api.state != null and sim.api.state.turn != null:
		sim.api.state.turn.card_ids_played_this_turn.append(card.id)
		sim.api.state.turn.card_types_played_this_turn.append(int(card.card_type))

	SimStatusSystem.on_card_played(sim.api, int(ctx.source_id), card)
	for i in range(card.actions.size()):
		var action := card.actions[i]
		ctx.current_action_index = i
		assert(action != null and action.activate_sim(ctx), "Card action failed for %s." % String(card.name))
	return ctx


func _apply_direct_damage(sim: Sim, source_id: int, target_id: int, amount: int) -> void:
	var damage_ctx := DamageContext.new()
	damage_ctx.source_id = source_id
	damage_ctx.target_id = target_id
	damage_ctx.base_amount = amount
	damage_ctx.reason = "verify_tempered_semantics"
	sim.api.resolve_damage_immediate(damage_ctx)


func _status_stacks(sim: Sim, target_id: int, status_id: StringName) -> int:
	return int(sim.api.get_status_stacks(target_id, status_id))
