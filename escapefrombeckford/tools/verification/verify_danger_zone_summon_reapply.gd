extends SceneTree

const ActionLifecycleSystem := preload("res://battle/sim/operators/action_lifecycle_system.gd")
const ActionPlanner := preload("res://battle/sim/operators/action_planner.gd")
const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CheckpointProcessor := preload("res://battle/sim/operators/checkpoint_processor.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const Keys := preload("res://core/keys_values/keys.gd")
const RemovalContext := preload("res://battle/contexts/removal_context.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")
const StatusContext := preload("res://battle/contexts/status_context.gd")

const CALABASH_DATA := preload("res://combatants/enemies/Calabash/calabash_data.tres")
const WEBER_DATA := preload("res://combatants/enemies/WeberPatrolArbalest/weber_patrol_arbalest_data.tres")
const SHIELD_IDEATION := preload("res://combatants/critters/ShieldIdeation/shield_ideation_data.tres")

const CALABASH_BURST_IDX := 0
const WEBER_QUARREL_SPRAY_IDX := 1
const DANGER_ZONE_ID := &"danger_zone"


func _init() -> void:
	_verify_calabash_reapplies_to_spawned_opponent()
	_verify_calabash_reapplies_to_remaining_opponent_after_target_loss()
	_verify_player_only_layout_change_stays_player_only()
	_verify_weber_reapply_prefers_opponent_over_player()
	print("verify_danger_zone_summon_reapply: ok")
	quit()


func _verify_calabash_reapplies_to_spawned_opponent() -> void:
	var setup := _make_sim_with_enemy(CALABASH_DATA, CALABASH_BURST_IDX)
	var sim := setup.get("sim") as Sim
	var enemy_id := int(setup.get("enemy_id", 0))
	var player_id := int(setup.get("player_id", 0))

	_apply_telegraph(sim, BattleState.FRIENDLY)
	assert(_status_stacks(sim, player_id, DANGER_ZONE_ID) == 1, "Calabash should telegraph Danger Zone onto the lone player.")

	var ally_id := int(sim.api.spawn_from_data(SHIELD_IDEATION, BattleState.FRIENDLY, 1, false))
	assert(ally_id > 0, "Verification ally should spawn into the player group.")
	_flush_planning(sim)

	assert(_status_stacks(sim, player_id, DANGER_ZONE_ID) == -1, "Player should lose Danger Zone once a summoned allied opponent appears behind them.")
	assert(_status_stacks(sim, ally_id, DANGER_ZONE_ID) == 1, "Spawned allied opponent should take Danger Zone even when the summon lands behind the player.")
	assert(_status_stacks(sim, enemy_id, DANGER_ZONE_ID) == -1, "Danger Zone should not land on the attacker.")


func _verify_calabash_reapplies_to_remaining_opponent_after_target_loss() -> void:
	var setup := _make_sim_with_enemy(CALABASH_DATA, CALABASH_BURST_IDX)
	var sim := setup.get("sim") as Sim
	var player_id := int(setup.get("player_id", 0))

	var front_ally_id := int(sim.api.spawn_from_data(SHIELD_IDEATION, BattleState.FRIENDLY, 0, false))
	var rear_ally_id := int(sim.api.spawn_from_data(SHIELD_IDEATION, BattleState.FRIENDLY, 2, false))
	assert(front_ally_id > 0 and rear_ally_id > 0, "Verification allies should spawn into the player group.")

	_apply_status(sim, int(setup.get("enemy_id", 0)), front_ally_id, DANGER_ZONE_ID, 1, "verify_existing_danger_zone_target")

	var removal_ctx := RemovalContext.new()
	removal_ctx.target_id = front_ally_id
	removal_ctx.reason = "verify_danger_zone_target_loss"
	sim.api.resolve_removal(removal_ctx)
	_flush_planning(sim)

	assert(_status_stacks(sim, front_ally_id, DANGER_ZONE_ID) == -1, "Removed ally should no longer have Danger Zone.")
	assert(_status_stacks(sim, rear_ally_id, DANGER_ZONE_ID) == 1, "Danger Zone should reapply to another allied opponent after the previous target is lost.")
	assert(_status_stacks(sim, player_id, DANGER_ZONE_ID) == -1, "Danger Zone should not fall back to the player while another allied opponent exists.")


func _verify_player_only_layout_change_stays_player_only() -> void:
	var setup := _make_sim_with_enemy(CALABASH_DATA, CALABASH_BURST_IDX)
	var sim := setup.get("sim") as Sim
	var player_id := int(setup.get("player_id", 0))

	_apply_telegraph(sim, BattleState.FRIENDLY)
	assert(_status_stacks(sim, player_id, DANGER_ZONE_ID) == 1, "Calabash should start by marking only the player.")

	sim.checkpoint_processor.request_group_layout_changed(
		BattleState.FRIENDLY,
		PackedInt32Array([player_id]),
		PackedInt32Array([player_id]),
		"verify_manual_player_only_layout_change"
	)
	_flush_planning(sim)

	assert(_status_stacks(sim, player_id, DANGER_ZONE_ID) == 1, "Player-only layout changes should not disturb the existing telegraph.")
	assert(sim.api.get_combatants_in_group(BattleState.FRIENDLY, false).size() == 1, "Negative case should keep the opposing group player-only.")


func _verify_weber_reapply_prefers_opponent_over_player() -> void:
	var setup := _make_sim_with_enemy(WEBER_DATA, WEBER_QUARREL_SPRAY_IDX)
	var sim := setup.get("sim") as Sim
	var player_id := int(setup.get("player_id", 0))

	_apply_telegraph(sim, BattleState.FRIENDLY)
	assert(_status_stacks(sim, player_id, DANGER_ZONE_ID) == 1, "Weber should telegraph onto the frontmost player.")

	var ally_id := int(sim.api.spawn_from_data(SHIELD_IDEATION, BattleState.FRIENDLY, 1, false))
	assert(ally_id > 0, "Verification ally should spawn for the Weber case.")
	_flush_planning(sim)

	assert(_status_stacks(sim, player_id, DANGER_ZONE_ID) == -1, "Weber reapply should move Danger Zone off the player once an allied opponent exists.")
	assert(_status_stacks(sim, ally_id, DANGER_ZONE_ID) == 1, "Weber reapply should prefer the allied opponent over the player regardless of frontmost order.")


func _make_sim_with_enemy(enemy_data, planned_action_idx: int) -> Dictionary:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(333, 777)
	sim.runtime.sim = sim
	sim.api.writer.allow_unscoped_events = true
	sim.api.writer.set_turn_context(1, BattleState.FRIENDLY, 0)

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)

	var enemy_id := _add_enemy_from_data(sim, enemy_data)
	var enemy := sim.api.state.get_unit(enemy_id)
	assert(enemy != null and enemy.combatant_data != null and enemy.combatant_data.ai != null, "Verification enemy must have AI data.")

	ActionPlanner.ensure_ai_state_initialized(enemy)
	enemy.ai_state[ActionPlanner.KEY_PLANNED_IDX] = planned_action_idx
	enemy.ai_state[Keys.PLANNED_SELECTION_SOURCE] = ActionPlanner.SELECTION_SOURCE_CHANCE
	enemy.ai_state[Keys.FIRST_INTENTS_READY] = true
	enemy.ai_state[Keys.IS_ACTING] = false

	return {
		"sim": sim,
		"enemy_id": enemy_id,
		"player_id": int(player.id),
	}


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


func _apply_telegraph(sim: Sim, group_index: int) -> void:
	ActionLifecycleSystem.on_group_turn_begin(sim.api, group_index)


func _flush_planning(sim: Sim) -> void:
	assert(sim != null and sim.checkpoint_processor != null, "Verification sim needs a checkpoint processor.")
	sim.checkpoint_processor.flush_planning(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, sim, true)


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
	var token = owner.statuses.get_status_token(status_id, false)
	return int(token.stacks) if token != null else -1
