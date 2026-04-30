extends SceneTree

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

const DISTANCE_HUNTER_CARD := preload("res://cards/souls/DistanceHunterCard/distance_hunter.tres")


func _init() -> void:
	var setup := _make_sim()
	var sim := setup.get("sim") as Sim
	var player_id := int(setup.get("player_id", 0))
	var hunter_id := _play_distance_hunter(sim, player_id)

	_flush_planning(sim)
	assert(_last_intent_text(sim, hunter_id) == "1", "Front-rank Distance Hunter should initially show base damage.")

	var move_ctx := MoveContext.new()
	move_ctx.actor_id = player_id
	move_ctx.move_unit_id = hunter_id
	move_ctx.move_type = MoveContext.MoveType.MOVE_TO_BACK
	move_ctx.reason = "verify_distance_hunter_intent_refresh"
	sim.api.resolve_move(move_ctx)
	_flush_planning(sim)

	assert(_last_intent_text(sim, hunter_id) == "3", "Distance Hunter intent should refresh after moving behind the front.")
	print("verify_distance_hunter_intent_refresh: ok")
	quit()


func _make_sim() -> Dictionary:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(515, 616)
	sim.runtime.sim = sim
	_configure_logging(sim)

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)

	return {
		"sim": sim,
		"player_id": int(player.id),
	}


func _configure_logging(sim: Sim) -> void:
	var scopes := BattleScopeManager.new()
	scopes.reset()
	sim.api.scopes = scopes
	sim.api.writer = BattleEventWriter.new(EventSinkMain.new(sim.state.events), scopes)
	sim.api.writer.allow_unscoped_events = true


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


func _play_distance_hunter(sim: Sim, player_id: int) -> int:
	var card := DISTANCE_HUNTER_CARD.make_runtime_instance()
	var ctx := CardContext.new()
	ctx.api = sim.api
	ctx.runtime = sim.runtime
	ctx.source_id = int(player_id)
	ctx.card_data = card
	ctx.insert_index = 0

	for action in card.actions:
		assert(action != null and action.activate_sim(ctx), "Distance Hunter action failed.")

	assert(ctx.summoned_ids.size() == 1, "Distance Hunter should summon exactly one unit.")
	return int(ctx.summoned_ids[0])


func _flush_planning(sim: Sim) -> void:
	assert(sim != null and sim.checkpoint_processor != null, "Verification sim needs a checkpoint processor.")
	sim.checkpoint_processor.flush_planning(CheckpointProcessor.Kind.AFTER_CARD, sim, true)


func _last_intent_text(sim: Sim, actor_id: int) -> String:
	for i in range(sim.state.events.size() - 1, -1, -1):
		var event := sim.state.events.get_event(i)
		if event == null or int(event.type) != int(BattleEvent.Type.SET_INTENT):
			continue
		if int(event.data.get(Keys.ACTOR_ID, 0)) != int(actor_id):
			continue
		return String(event.data.get(Keys.INTENT_TEXT, ""))
	return ""
