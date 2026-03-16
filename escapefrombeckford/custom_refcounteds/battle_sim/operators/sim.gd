# sim.gd
class_name Sim extends RefCounted

var state: BattleState
var api: SimBattleAPI
var intent_planner: IntentPlanner
var checkpoint_processor: CheckpointProcessor
var resolver: Resolver

var status_catalog: StatusCatalog
var arcana_catalog: ArcanaCatalog

var is_preview: bool = false


func init_from_seeds(battle_seed: int, run_seed: int) -> void:
	state = BattleState.new()
	state.init(int(battle_seed), int(run_seed))
	state._next_sim_id = 1

	if status_catalog:
		state.status_catalog = status_catalog
	if arcana_catalog:
		state.arcana_catalog = arcana_catalog

	api = SimBattleAPI.new(state)
	api.status_catalog = status_catalog

	_init_services()


func init_from_cloned_state(cloned_state: BattleState) -> void:
	state = cloned_state

	if status_catalog:
		state.status_catalog = status_catalog
	if arcana_catalog:
		state.arcana_catalog = arcana_catalog

	api = SimBattleAPI.new(state)
	api.status_catalog = status_catalog

	_init_services()


func _init_services() -> void:
	intent_planner = IntentPlanner.new()
	checkpoint_processor = CheckpointProcessor.new()
	api.checkpoint_processor = checkpoint_processor
	resolver = Resolver.new()


func clone_for_preview() -> Sim:
	var s := Sim.new()
	s.status_catalog = status_catalog
	s.arcana_catalog = arcana_catalog
	s.is_preview = true

	if state != null:
		s.init_from_cloned_state(state.clone())

	return s
