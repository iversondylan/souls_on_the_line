extends SceneTree

const ActionPlanner := preload("res://battle/sim/operators/action_planner.gd")
const BattleEvent := preload("res://battle/sim/containers/battle_event.gd")
const BattleEventWriter := preload("res://battle/sim/logging/battle_event_writer.gd")
const BattleScopeManager := preload("res://battle/sim/operators/battle_scope_manager.gd")
const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CheckpointProcessor := preload("res://battle/sim/operators/checkpoint_processor.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const EventSinkMain := preload("res://battle/sim/logging/event_sink_main.gd")
const Keys := preload("res://core/keys_values/keys.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")

const CALABASH_DATA := preload("res://combatants/enemies/Calabash/calabash_data.tres")


func _init() -> void:
	_verify_fresh_cycle_stays_deferred_until_checkpoint()
	_verify_fresh_cycle_resets_before_replan()
	_verify_inline_fallback_replans_and_publishes_immediately()
	_verify_generic_deferred_replan_still_uses_checkpoint()
	print("verify_actor_end_intent_checkpoint: ok")
	quit()


func _verify_fresh_cycle_stays_deferred_until_checkpoint() -> void:
	var setup := _make_sim_with_enemy()
	var sim := setup.get("sim") as Sim
	var enemy_id := int(setup.get("enemy_id", 0))
	var enemy := _get_enemy(sim, enemy_id)
	var event_count_before := sim.state.events.size()

	sim.api.request_fresh_intent_cycle(enemy_id, true)

	assert(
		int(enemy.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) == 0,
		"Fresh intent cycle should not mutate planned state until the checkpoint flush runs."
	)
	assert(
		_count_set_intent_events(sim, enemy_id, event_count_before) == 0,
		"Fresh intent cycle should not publish intent before the checkpoint flush."
	)

	_flush_planning(sim)

	assert(
		int(enemy.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) >= 0,
		"Checkpoint flush should produce a fresh planned intent."
	)
	assert(
		_count_set_intent_events(sim, enemy_id, event_count_before) >= 1,
		"Checkpoint flush should publish the refreshed actor intent."
	)


func _verify_fresh_cycle_resets_before_replan() -> void:
	var setup := _make_sim_with_enemy()
	var sim := setup.get("sim") as Sim
	var enemy_id := int(setup.get("enemy_id", 0))
	var enemy := _get_enemy(sim, enemy_id)

	enemy.ai_state[ActionPlanner.STABILITY_BROKEN] = true
	enemy.ai_state[Keys.IS_ACTING] = true
	enemy.ai_state[Keys.FIRST_INTENTS_READY] = false
	enemy.ai_state[Keys.PLANNED_SELECTION_SOURCE] = ActionPlanner.SELECTION_SOURCE_OVERRIDE

	sim.api.request_fresh_intent_cycle(enemy_id, true)
	_flush_planning(sim)

	assert(
		!bool(enemy.ai_state.get(ActionPlanner.STABILITY_BROKEN, true)),
		"Fresh checkpoint replans should clear stability-broken state before replanning."
	)
	assert(
		!bool(enemy.ai_state.get(Keys.IS_ACTING, true)),
		"Fresh checkpoint replans should clear acting state before replanning."
	)
	assert(
		bool(enemy.ai_state.get(Keys.FIRST_INTENTS_READY, false)),
		"Fresh checkpoint replans should mark first intents ready."
	)
	assert(
		int(enemy.ai_state.get(Keys.PLANNED_SELECTION_SOURCE, ActionPlanner.SELECTION_SOURCE_NONE)) != int(ActionPlanner.SELECTION_SOURCE_OVERRIDE),
		"Fresh checkpoint replans should rebuild selection source from a clean actor-end state."
	)


func _verify_inline_fallback_replans_and_publishes_immediately() -> void:
	var setup := _make_sim_with_enemy()
	var sim := setup.get("sim") as Sim
	var enemy_id := int(setup.get("enemy_id", 0))
	var enemy := _get_enemy(sim, enemy_id)
	var event_count_before := sim.state.events.size()

	sim.api.checkpoint_processor = null
	sim.checkpoint_processor = null
	enemy.ai_state[ActionPlanner.STABILITY_BROKEN] = true
	enemy.ai_state[Keys.IS_ACTING] = true
	enemy.ai_state[Keys.FIRST_INTENTS_READY] = false
	enemy.ai_state[ActionPlanner.KEY_PLANNED_IDX] = 0

	sim.api.request_fresh_intent_cycle(enemy_id, true)

	assert(
		int(enemy.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) >= 0,
		"Inline fresh-cycle fallback should immediately replan the actor."
	)
	assert(
		!bool(enemy.ai_state.get(ActionPlanner.STABILITY_BROKEN, true)),
		"Inline fresh-cycle fallback should clear stability-broken state."
	)
	assert(
		!bool(enemy.ai_state.get(Keys.IS_ACTING, true)),
		"Inline fresh-cycle fallback should clear acting state."
	)
	assert(
		_count_set_intent_events(sim, enemy_id, event_count_before) >= 1,
		"Inline fresh-cycle fallback should publish the intent immediately."
	)


func _verify_generic_deferred_replan_still_uses_checkpoint() -> void:
	var setup := _make_sim_with_enemy()
	var sim := setup.get("sim") as Sim
	var enemy_id := int(setup.get("enemy_id", 0))
	var enemy := _get_enemy(sim, enemy_id)
	var event_count_before := sim.state.events.size()

	enemy.ai_state[ActionPlanner.KEY_PLANNED_IDX] = -1
	sim.api._request_replan(enemy_id)

	assert(
		int(enemy.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) == -1,
		"Generic deferred replans should still wait for the checkpoint before mutating intent state."
	)
	assert(
		_count_set_intent_events(sim, enemy_id, event_count_before) == 0,
		"Generic deferred replans should still avoid publishing before the checkpoint."
	)

	_flush_planning(sim)

	assert(
		int(enemy.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) >= 0,
		"Generic deferred replans should still resolve during the checkpoint flush."
	)
	assert(
		_count_set_intent_events(sim, enemy_id, event_count_before) >= 1,
		"Generic deferred replans should still publish via the checkpoint path."
	)


func _make_sim_with_enemy() -> Dictionary:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(444, 888)
	sim.runtime.sim = sim
	_configure_logging(sim)
	sim.api.writer.set_turn_context(1, BattleState.ENEMY, 0)

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)

	var enemy_id := _add_enemy_from_data(sim, CALABASH_DATA)
	var enemy := _get_enemy(sim, enemy_id)
	assert(enemy != null and enemy.combatant_data != null and enemy.combatant_data.ai != null, "Verification enemy must have AI data.")

	ActionPlanner.ensure_ai_state_initialized(enemy)
	enemy.ai_state[ActionPlanner.KEY_PLANNED_IDX] = 0
	enemy.ai_state[Keys.PLANNED_SELECTION_SOURCE] = ActionPlanner.SELECTION_SOURCE_CHANCE
	enemy.ai_state[Keys.FIRST_INTENTS_READY] = true
	enemy.ai_state[Keys.IS_ACTING] = false

	return {
		"sim": sim,
		"enemy_id": enemy_id,
		"player_id": int(player.id),
	}


func _configure_logging(sim: Sim) -> void:
	var scopes := BattleScopeManager.new()
	scopes.reset()
	sim.api.scopes = scopes
	sim.api.writer = BattleEventWriter.new(EventSinkMain.new(sim.state.events), scopes)
	sim.api.writer.allow_unscoped_events = true


func _make_unit(
	state,
	name: String,
	group_index: int,
	combatant_type: int,
	max_health: int,
	ap: int
) -> CombatantState:
	var unit := CombatantState.new()
	unit.id = state.alloc_id()
	unit.name = name
	unit.team = group_index
	unit.type = combatant_type
	unit.mortality = CombatantState.Mortality.MORTAL
	unit.max_health = max_health
	unit.health = max_health
	unit.ap = ap
	unit.alive = true
	state.add_unit(unit, group_index)
	return unit


func _add_enemy_from_data(sim: Sim, data) -> int:
	var unit := CombatantState.new()
	unit.id = sim.state.alloc_id()
	unit.type = CombatantView.Type.ENEMY
	unit.mortality = CombatantState.Mortality.MORTAL
	unit.init_from_combatant_data(data)
	unit.alive = true
	sim.state.add_unit(unit, BattleState.ENEMY)
	return int(unit.id)


func _flush_planning(sim: Sim) -> void:
	assert(sim != null and sim.checkpoint_processor != null, "Verification sim needs a checkpoint processor.")
	sim.checkpoint_processor.flush_planning(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, sim, true)


func _get_enemy(sim: Sim, enemy_id: int) -> CombatantState:
	if sim == null or sim.api == null or sim.api.state == null:
		return null
	return sim.api.state.get_unit(int(enemy_id))


func _count_set_intent_events(sim: Sim, actor_id: int, start_index: int = 0) -> int:
	if sim == null or sim.state == null or sim.state.events == null:
		return 0
	var count := 0
	for i in range(start_index, sim.state.events.size()):
		var event := sim.state.events.get_event(i)
		if event == null or int(event.type) != int(BattleEvent.Type.SET_INTENT):
			continue
		if int(event.data.get(Keys.ACTOR_ID, 0)) != int(actor_id):
			continue
		count += 1
	return count
