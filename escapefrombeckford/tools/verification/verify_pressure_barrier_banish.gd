extends SceneTree

const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const DamageContext := preload("res://battle/contexts/damage_context.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")
const StatusContext := preload("res://battle/contexts/status_context.gd")

const PRESSURE_BARRIER_ID := &"pressure_barrier"
const COMBATANT_TYPE_ALLY := 0
const COMBATANT_TYPE_ENEMY := 1
const COMBATANT_TYPE_PLAYER := 2


func _init() -> void:
	_verify_pressure_barrier_reduces_pure_banish_damage_on_soul_ally()
	_verify_pressure_barrier_reduces_mixed_damage_once()
	print("verify_pressure_barrier_banish: ok")
	quit()


func _verify_pressure_barrier_reduces_pure_banish_damage_on_soul_ally() -> void:
	var setup := _make_sim()
	var sim := setup.get("sim") as Sim
	var enemy_id := int(setup.get("enemy_id", 0))
	var ally_id := int(setup.get("ally_id", 0))
	var ally := sim.api.state.get_unit(ally_id)

	_apply_pressure_barrier(sim, ally_id, 3)
	var damage_ctx := _apply_direct_damage(sim, enemy_id, ally_id, 0, 5)

	assert(int(damage_ctx.health_damage) == 2, "Pressure Barrier 3 should reduce 5 banish damage to 2.")
	assert(int(damage_ctx.applied_banish_amount) == 2, "The reduced hit should keep only 2 applied banish damage.")
	assert(int(ally.health) == 8, "Soul ally should lose only 2 health to reduced banish damage.")
	assert(_status_stacks(sim, ally_id, PRESSURE_BARRIER_ID) == 2, "Pressure Barrier should lose one stack after the hit.")


func _verify_pressure_barrier_reduces_mixed_damage_once() -> void:
	var setup := _make_sim()
	var sim := setup.get("sim") as Sim
	var enemy_id := int(setup.get("enemy_id", 0))
	var ally_id := int(setup.get("ally_id", 0))
	var ally := sim.api.state.get_unit(ally_id)

	_apply_pressure_barrier(sim, ally_id, 3)
	var damage_ctx := _apply_direct_damage(sim, enemy_id, ally_id, 2, 5)

	assert(int(damage_ctx.health_damage) == 4, "Pressure Barrier 3 should reduce a 7 total mixed hit to 4, not reduce both components separately.")
	assert(int(damage_ctx.applied_banish_amount) == 2, "Mixed damage mitigation should trim banish damage after preserving normal damage first.")
	assert(int(ally.health) == 6, "Soul ally should lose 4 health to the reduced mixed hit.")


func _make_sim() -> Dictionary:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(424, 909)
	sim.runtime.sim = sim
	sim.api.writer.allow_unscoped_events = true

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, COMBATANT_TYPE_PLAYER, CombatantState.Mortality.MORTAL, 30)
	var ally := _make_unit(sim.state, "Soul Ally", BattleState.FRIENDLY, COMBATANT_TYPE_ALLY, CombatantState.Mortality.BOUND, 10)
	var enemy := _make_unit(sim.state, "Enemy", BattleState.ENEMY, COMBATANT_TYPE_ENEMY, CombatantState.Mortality.MORTAL, 30)

	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)
	sim.api.writer.set_turn_context(1, BattleState.ENEMY, int(enemy.id))

	return {
		"sim": sim,
		"ally_id": int(ally.id),
		"enemy_id": int(enemy.id),
	}


func _make_unit(
	state: BattleState,
	name: String,
	group_index: int,
	combatant_type: int,
	mortality: CombatantState.Mortality,
	max_health: int
) -> CombatantState:
	var unit := CombatantState.new()
	unit.id = state.alloc_id()
	unit.name = name
	unit.type = combatant_type
	unit.mortality = mortality
	unit.max_health = max_health
	unit.health = max_health
	unit.alive = true
	state.add_unit(unit, group_index)
	return unit


func _apply_pressure_barrier(sim: Sim, target_id: int, stacks: int) -> void:
	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(sim.api.get_player_id())
	status_ctx.target_id = target_id
	status_ctx.status_id = PRESSURE_BARRIER_ID
	status_ctx.stacks = stacks
	status_ctx.reason = "verify_pressure_barrier_banish"
	sim.api.apply_status(status_ctx)


func _apply_direct_damage(
	sim: Sim,
	source_id: int,
	target_id: int,
	normal_amount: int,
	banish_amount: int
) -> DamageContext:
	var damage_ctx := DamageContext.new()
	damage_ctx.source_id = source_id
	damage_ctx.target_id = target_id
	damage_ctx.base_amount = normal_amount
	damage_ctx.base_banish_amount = banish_amount
	damage_ctx.reason = "verify_pressure_barrier_banish"
	sim.api.resolve_damage_immediate(damage_ctx)
	return damage_ctx


func _status_stacks(sim: Sim, target_id: int, status_id: StringName) -> int:
	return int(sim.api.get_status_stacks(target_id, status_id))
