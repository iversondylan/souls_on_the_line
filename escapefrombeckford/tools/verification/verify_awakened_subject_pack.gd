extends SceneTree

const ActionPlanner := preload("res://battle/sim/operators/action_planner.gd")
const BattleEvent := preload("res://battle/sim/containers/battle_event.gd")
const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const Keys := preload("res://core/keys_values/keys.gd")
const NPCAIContext := preload("res://npc_ai/_core/npc_ai_context.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const SimStatusSystem := preload("res://battle/sim/operators/sim_status_system.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")
const StatusContext := preload("res://battle/contexts/status_context.gd")

const AWAKENED_SUBJECT := preload("res://combatants/enemies/AwakenedSubject/awakened_subject_data.tres")
const SHIELD_IDEATION := preload("res://combatants/critters/ShieldIdeation/shield_ideation_data.tres")
const DAGGER_IDEATION := preload("res://combatants/critters/DaggerIdeation/dagger_ideation_data.tres")
const SCRAPMEN_TRUNCHEONER := preload("res://combatants/enemies/ScrapmenTruncheoner/scrapmen_truncheoner_data.tres")
const AWAKENED_SUBJECT_ENCOUNTER := preload("res://encounters/beckford_domain/tier_1_awakened_subject.tres")
const BATTLE_POOL_1 := preload("res://encounters/battle_pool_1.tres")

const IDEATE_ARMS_IDX := 0
const TWIN_THEORY_IDX := 1
const EXPOSE_WEAKNESS_IDX := 2
const BLINDING_ASSAULT_IDX := 1

const ABSORB_ID := &"absorb"
const SMALL_ID := &"small"
const VULNERABLE_ID := &"vulnerable"
const VULNERABLE_AURA_ID := &"vulnerable_aura"
const WEAKENED_ID := &"weakened"

func _init() -> void:
	_verify_action_weights()
	_verify_ideate_arms_execution()
	_verify_critter_data()
	_verify_expose_weakness_projection()
	_verify_scrapmen_migration()
	_verify_encounter_pool()
	_verify_status_catalog()
	print("verify_awakened_subject_pack: ok")
	quit()

func _verify_action_weights() -> void:
	var setup := _make_sim_with_subject()
	var sim := setup.get("sim") as Sim
	var subject_id := int(setup.get("subject_id", 0))
	var subject := sim.api.state.get_unit(subject_id)
	assert(subject != null, "Awakened Subject should exist in the verification sim.")

	var ideate_first_turn := _action_weight(sim, subject_id, IDEATE_ARMS_IDX)
	var twin_first_turn := _action_weight(sim, subject_id, TWIN_THEORY_IDX)
	var expose_first_turn := _action_weight(sim, subject_id, EXPOSE_WEAKNESS_IDX)
	assert(
		ideate_first_turn > (twin_first_turn * 50.0) and ideate_first_turn > (expose_first_turn * 50.0),
		"Ideate Arms should dominate first-turn planning."
	)

	_add_dummy_enemy(sim, "Enemy Dummy 1")
	_add_dummy_enemy(sim, "Enemy Dummy 2")
	_add_dummy_enemy(sim, "Enemy Dummy 3")
	assert(
		is_zero_approx(_action_weight(sim, subject_id, IDEATE_ARMS_IDX)),
		"Ideate Arms should be disabled once the actor's group reaches four units."
	)

	subject.ai_state[Keys.ACTIONS_PERFORMED_COUNT] = 1
	_set_action_spree(subject, IDEATE_ARMS_IDX, 2)
	var ideate_spree_weight := _action_weight(sim, subject_id, IDEATE_ARMS_IDX)
	assert(
		is_equal_approx(ideate_spree_weight, 0.45 * pow(0.25, 2.0)),
		"Ideate Arms should use quarter-exponential spree scaling."
	)

	subject.ai_state[Keys.ACTIONS_PERFORMED_COUNT] = 1
	_set_action_spree(subject, TWIN_THEORY_IDX, 2)
	_set_action_spree(subject, EXPOSE_WEAKNESS_IDX, 2)
	assert(
		is_equal_approx(_action_weight(sim, subject_id, TWIN_THEORY_IDX), 1.0 * pow(0.5, 2.0)),
		"Twin Theory should use half-exponential spree scaling."
	)
	assert(
		is_equal_approx(_action_weight(sim, subject_id, EXPOSE_WEAKNESS_IDX), 0.85 * pow(0.5, 2.0)),
		"Expose Weakness should use half-exponential spree scaling."
	)

func _verify_ideate_arms_execution() -> void:
	var setup := _make_sim_with_subject()
	var sim := setup.get("sim") as Sim
	var subject_id := int(setup.get("subject_id", 0))
	var ctx: NPCAIContext = _run_npc_action(sim, subject_id, IDEATE_ARMS_IDX)
	var enemy_order := sim.api.get_combatants_in_group(BattleState.ENEMY, false)

	assert(int(ctx.summoned_ids.size()) == 2, "Ideate Arms should summon exactly two ideations.")
	assert(int(enemy_order.size()) == 3, "Enemy group should contain Subject plus two ideations after Ideate Arms.")

	var front_id := int(enemy_order[0])
	var rear_id := int(enemy_order[-1])
	var middle_id := int(enemy_order[1])
	var front := sim.api.state.get_unit(front_id)
	var rear := sim.api.state.get_unit(rear_id)
	var middle := sim.api.state.get_unit(middle_id)

	assert(front != null and String(front.name) == "Shield Ideation", "Shield Ideation should be inserted at the front.")
	assert(rear != null and String(rear.name) == "Dagger Ideation", "Dagger Ideation should be inserted at the rear.")
	assert(middle != null and String(middle.name) == "Awakened Subject", "Awakened Subject should remain between the ideations.")
	assert(_status_stacks(sim, front_id, ABSORB_ID) == 1, "Shield Ideation should receive Absorb 1.")
	assert(_status_stacks(sim, front_id, SMALL_ID) == 1, "Shield Ideation should receive Small.")
	assert(_status_stacks(sim, rear_id, ABSORB_ID) == -1, "Dagger Ideation should not receive Absorb.")
	assert(_status_stacks(sim, rear_id, SMALL_ID) == -1, "Dagger Ideation should not receive Small.")
	assert(int(front.ap) == 1 and int(front.max_health) == 3, "Shield Ideation should have exact 1/3 stats.")
	assert(int(rear.ap) == 6 and int(rear.max_health) == 3, "Dagger Ideation should have exact 6/3 stats.")

func _verify_critter_data() -> void:
	assert(int(SHIELD_IDEATION.ap) == 1 and int(SHIELD_IDEATION.max_health) == 3, "Shield Ideation data should be 1/3.")
	assert(int(DAGGER_IDEATION.ap) == 6 and int(DAGGER_IDEATION.max_health) == 3, "Dagger Ideation data should be 6/3.")
	assert(_combatant_is_melee_only(SHIELD_IDEATION), "Shield Ideation should be melee-only.")
	assert(_combatant_is_melee_only(DAGGER_IDEATION), "Dagger Ideation should be melee-only.")

func _verify_expose_weakness_projection() -> void:
	var setup := _make_sim_with_subject()
	var sim := setup.get("sim") as Sim
	var subject_id := int(setup.get("subject_id", 0))
	var player_id := int(setup.get("player_id", 0))
	var ally_id := int(setup.get("ally_id", 0))
	var event_count_before := sim.state.events.size()

	_run_npc_action(sim, subject_id, EXPOSE_WEAKNESS_IDX)

	assert(_status_stacks(sim, subject_id, VULNERABLE_AURA_ID) == 2, "Expose Weakness should apply Vulnerable Aura 2 to self.")
	assert(_status_stacks(sim, player_id, WEAKENED_ID) == 1, "Expose Weakness should apply Weakened to the player.")
	assert(_status_stacks(sim, ally_id, WEAKENED_ID) == 1, "Expose Weakness should apply Weakened to allied opponents.")
	assert(_has_projected_status(sim, player_id, VULNERABLE_ID), "Vulnerable Aura should project Vulnerable to the player.")
	assert(_has_projected_status(sim, ally_id, VULNERABLE_ID), "Vulnerable Aura should project Vulnerable to allied opponents.")
	assert(
		!_has_direct_status(sim, player_id, VULNERABLE_ID) and !_has_direct_status(sim, ally_id, VULNERABLE_ID),
		"Vulnerable should be projected only, not directly owned by opponents."
	)
	assert(
		_count_status_events(sim, VULNERABLE_AURA_ID, subject_id, event_count_before) == 0,
		"Hidden Vulnerable Aura should not emit direct owner status events."
	)
	assert(
		_count_projected_status_events(sim, VULNERABLE_ID, player_id, event_count_before) >= 1,
		"Projected Vulnerable should emit target-side status events for view sync."
	)
	assert(
		_latest_projected_status_event(sim, VULNERABLE_ID, player_id, event_count_before).get(Keys.PROJECTION_SOURCE_STATUS_ID, &"") == VULNERABLE_AURA_ID,
		"Projected Vulnerable events should carry their source aura metadata."
	)

	var event_count_after_first_aura := sim.state.events.size()
	var second_subject_id := _add_enemy_from_data(sim, AWAKENED_SUBJECT, "Awakened Subject 2")
	_apply_status(sim, second_subject_id, second_subject_id, VULNERABLE_AURA_ID, 2, "verify_second_vulnerable_aura")
	assert(
		_count_projected_status_events(sim, VULNERABLE_ID, player_id, event_count_after_first_aura) == 0,
		"A second Vulnerable Aura should not create a second projected Vulnerable badge on the same target."
	)

	SimStatusSystem.on_actor_turn_end(sim.api, subject_id)
	assert(_status_stacks(sim, subject_id, VULNERABLE_AURA_ID) == 1, "Vulnerable Aura should tick down at the end of its owner's turn.")
	assert(_has_projected_status(sim, player_id, VULNERABLE_ID), "Projected Vulnerable should persist while the aura remains active.")

	SimStatusSystem.on_actor_turn_end(sim.api, subject_id)
	assert(_status_stacks(sim, subject_id, VULNERABLE_AURA_ID) == -1, "Vulnerable Aura should fully expire after its second owner turn end.")
	assert(_has_projected_status(sim, player_id, VULNERABLE_ID), "A second active aura should keep Vulnerable projected on the target.")

	SimStatusSystem.on_actor_turn_end(sim.api, second_subject_id)
	SimStatusSystem.on_actor_turn_end(sim.api, second_subject_id)
	assert(!_has_projected_status(sim, player_id, VULNERABLE_ID), "Projected Vulnerable should clear once all source auras expire.")

func _verify_scrapmen_migration() -> void:
	var setup := _make_sim_with_enemy(SCRAPMEN_TRUNCHEONER, "Scrapmen Truncheoner")
	var sim := setup.get("sim") as Sim
	var enemy_id := int(setup.get("enemy_id", 0))
	var player_id := int(setup.get("player_id", 0))
	var ally_id := int(setup.get("ally_id", 0))
	var event_count_before := sim.state.events.size()

	_run_npc_action(sim, enemy_id, BLINDING_ASSAULT_IDX)

	assert(_status_stacks(sim, enemy_id, VULNERABLE_AURA_ID) == 2, "Scrapmen Truncheoner should now self-apply Vulnerable Aura 2.")
	assert(_status_stacks(sim, player_id, WEAKENED_ID) == 1, "Blinding Assault should still weaken the player.")
	assert(_status_stacks(sim, ally_id, WEAKENED_ID) == 1, "Blinding Assault should still weaken allied opponents.")
	assert(_has_projected_status(sim, player_id, VULNERABLE_ID), "Blinding Assault should project Vulnerable onto the player.")
	assert(
		_count_status_events(sim, VULNERABLE_AURA_ID, enemy_id, event_count_before) == 0,
		"Scrapmen Truncheoner's hidden Vulnerable Aura should not emit owner status events."
	)

func _verify_encounter_pool() -> void:
	assert(AWAKENED_SUBJECT_ENCOUNTER != null, "Awakened Subject encounter resource should load.")
	assert(String(AWAKENED_SUBJECT_ENCOUNTER.encounter_name) == "Awakened Subject", "Encounter should be named Awakened Subject.")
	assert(int(AWAKENED_SUBJECT_ENCOUNTER.battle_tier) == 1, "Awakened Subject encounter should be tier 1.")
	assert(int(AWAKENED_SUBJECT_ENCOUNTER.enemies.size()) == 1, "Awakened Subject encounter should be solo.")
	assert(
		AWAKENED_SUBJECT_ENCOUNTER.enemies[0] != null and String(AWAKENED_SUBJECT_ENCOUNTER.enemies[0].name) == "Awakened Subject",
		"Awakened Subject encounter should spawn the new enemy."
	)

	var found := false
	for battle in BATTLE_POOL_1.pool:
		if battle == AWAKENED_SUBJECT_ENCOUNTER:
			found = true
			break
	assert(found, "Battle pool 1 should include the Awakened Subject encounter.")

func _verify_status_catalog() -> void:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()
	assert(status_catalog.get_proto(VULNERABLE_AURA_ID) != null, "Status catalog should include Vulnerable Aura.")
	assert(status_catalog.get_proto(VULNERABLE_ID) != null, "Status catalog should include Vulnerable.")

func _make_sim_with_subject() -> Dictionary:
	var setup := _make_base_sim()
	var sim := setup.get("sim") as Sim
	var subject_id := _add_enemy_from_data(sim, AWAKENED_SUBJECT)
	setup["subject_id"] = subject_id
	setup["enemy_id"] = subject_id
	return setup

func _make_sim_with_enemy(enemy_data, label := "") -> Dictionary:
	var setup := _make_base_sim()
	var sim := setup.get("sim") as Sim
	var enemy_id := _add_enemy_from_data(sim, enemy_data, label)
	setup["enemy_id"] = enemy_id
	return setup

func _make_base_sim() -> Dictionary:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(111, 222)
	sim.runtime.sim = sim
	sim.api.writer.allow_unscoped_events = true
	sim.api.writer.set_turn_context(1, BattleState.FRIENDLY, 0)

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	var ally := _make_unit(sim.state, "Ally", BattleState.FRIENDLY, CombatantView.Type.ALLY, 12, 4)
	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)

	return {
		"sim": sim,
		"player_id": int(player.id),
		"ally_id": int(ally.id),
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

func _add_enemy_from_data(sim: Sim, data, label := "") -> int:
	var unit := CombatantState.new()
	unit.id = sim.state.alloc_id()
	unit.type = CombatantView.Type.ENEMY
	unit.mortality = CombatantState.Mortality.MORTAL
	unit.init_from_combatant_data(data)
	if !String(label).is_empty():
		unit.name = label
	unit.alive = true
	sim.state.add_unit(unit, BattleState.ENEMY)
	return int(unit.id)

func _add_dummy_enemy(sim: Sim, name: String) -> int:
	var dummy := _make_unit(sim.state, name, BattleState.ENEMY, CombatantView.Type.ENEMY, 5, 1)
	return int(dummy.id)

func _run_npc_action(sim: Sim, actor_id: int, action_idx: int):
	var actor := sim.api.state.get_unit(actor_id)
	assert(actor != null and actor.combatant_data != null and actor.combatant_data.ai != null, "NPC actor must have AI data.")

	ActionPlanner.ensure_ai_state_initialized(actor)
	actor.ai_state[ActionPlanner.KEY_PLANNED_IDX] = action_idx
	actor.ai_state[Keys.PLANNED_SELECTION_SOURCE] = ActionPlanner.SELECTION_SOURCE_CHANCE

	sim.api.writer.set_turn_context(1, int(actor.team), actor_id)

	var ctx := ActionPlanner.make_context(sim.api, actor)
	ctx.runtime = sim.runtime
	ctx.summoned_ids = PackedInt32Array()
	ctx.affected_ids = PackedInt32Array()
	ctx.state[Keys.IS_ACTING] = true

	var action = actor.combatant_data.ai.actions[action_idx]
	for sm in action.state_models:
		if sm != null:
			sm.change_state_sim(ctx)

	for pkg in action.effect_packages:
		if pkg == null:
			continue
		ctx.params.clear()
		for sm2 in pkg.state_models:
			if sm2 != null:
				sm2.change_state_sim(ctx)
		for pm in pkg.param_models:
			if pm != null:
				pm.change_params_sim(ctx)
		if pkg.effect != null:
			pkg.effect.execute(ctx)

	ctx.state[Keys.IS_ACTING] = false
	return ctx

func _action_weight(sim: Sim, actor_id: int, action_idx: int) -> float:
	var actor := sim.api.state.get_unit(actor_id)
	assert(actor != null and actor.combatant_data != null and actor.combatant_data.ai != null, "NPC actor must have AI data.")
	ActionPlanner.ensure_ai_state_initialized(actor)
	var ctx := ActionPlanner.make_context(sim.api, actor)
	var action = actor.combatant_data.ai.actions[action_idx]
	return float(ActionPlanner._get_action_chance_weight_sim(action, action_idx, ctx))

func _set_action_spree(actor: CombatantState, action_idx: int, spree: int) -> void:
	ActionPlanner.ensure_ai_state_initialized(actor)
	var action_state := ActionPlanner.ensure_action_state_sim(actor.ai_state, action_idx)
	action_state[Keys.SPREE] = spree

func _apply_status(sim: Sim, source_id: int, target_id: int, status_id: StringName, stacks: int, reason: String) -> void:
	var status_ctx := StatusContext.new()
	status_ctx.source_id = source_id
	status_ctx.target_id = target_id
	status_ctx.status_id = status_id
	status_ctx.stacks = stacks
	status_ctx.reason = reason
	sim.api.apply_status(status_ctx)

func _status_stacks(sim: Sim, owner_id: int, status_id: StringName) -> int:
	if sim == null or sim.api == null or sim.api.state == null:
		return -1
	var owner := sim.api.state.get_unit(owner_id)
	if owner == null or owner.statuses == null:
		return -1
	var token := owner.statuses.get_status_token(status_id, false)
	return int(token.stacks) if token != null else -1

func _has_direct_status(sim: Sim, owner_id: int, status_id: StringName) -> bool:
	if sim == null or sim.api == null or sim.api.state == null:
		return false
	var owner := sim.api.state.get_unit(owner_id)
	return owner != null and owner.statuses != null and owner.statuses.get_status_token(status_id, false) != null

func _has_projected_status(sim: Sim, owner_id: int, status_id: StringName) -> bool:
	if sim == null or sim.api == null or sim.api.state == null:
		return false
	var owner := sim.api.state.get_unit(owner_id)
	return owner != null and owner.statuses != null and owner.statuses.get_projected_status_token(status_id) != null

func _count_status_events(sim: Sim, status_id: StringName, target_id: int, start_index: int = 0) -> int:
	var total := 0
	for i in range(start_index, sim.state.events.size()):
		var event := sim.state.events.get_event(i)
		if event == null or int(event.type) != int(BattleEvent.Type.STATUS):
			continue
		if StringName(event.data.get(Keys.STATUS_ID, &"")) != status_id:
			continue
		if int(event.data.get(Keys.TARGET_ID, 0)) != int(target_id):
			continue
		total += 1
	return total

func _count_projected_status_events(sim: Sim, status_id: StringName, target_id: int, start_index: int = 0) -> int:
	var total := 0
	for i in range(start_index, sim.state.events.size()):
		var event := sim.state.events.get_event(i)
		if event == null or int(event.type) != int(BattleEvent.Type.STATUS):
			continue
		if StringName(event.data.get(Keys.STATUS_ID, &"")) != status_id:
			continue
		if int(event.data.get(Keys.TARGET_ID, 0)) != int(target_id):
			continue
		var status_data: Dictionary = {}
		var raw_status_data = event.data.get(Keys.STATUS_DATA, {})
		if raw_status_data is Dictionary:
			status_data = raw_status_data
		if !(status_data is Dictionary) or !bool(status_data.get(Keys.IS_PROJECTED, false)):
			continue
		total += 1
	return total

func _latest_projected_status_event(sim: Sim, status_id: StringName, target_id: int, start_index: int = 0) -> Dictionary:
	for i in range(sim.state.events.size() - 1, start_index - 1, -1):
		var event := sim.state.events.get_event(i)
		if event == null or int(event.type) != int(BattleEvent.Type.STATUS):
			continue
		if StringName(event.data.get(Keys.STATUS_ID, &"")) != status_id:
			continue
		if int(event.data.get(Keys.TARGET_ID, 0)) != int(target_id):
			continue
		var status_data: Dictionary = {}
		var raw_status_data = event.data.get(Keys.STATUS_DATA, {})
		if raw_status_data is Dictionary:
			status_data = raw_status_data
		if status_data is Dictionary and bool(status_data.get(Keys.IS_PROJECTED, false)):
			return status_data
	return {}

func _combatant_is_melee_only(data) -> bool:
	if data == null or data.ai == null or data.ai.actions.is_empty():
		return false
	var action = data.ai.actions[0]
	if action == null or action.effect_packages.is_empty():
		return false
	var pkg = action.effect_packages[0]
	if pkg == null or pkg.param_models == null:
		return false
	for model in pkg.param_models:
		if model == null or model.get_script() == null:
			continue
		if String(model.get_script().resource_path) == "res://npc_ai/attack_mode/melee_model.gd":
			return true
	return false
