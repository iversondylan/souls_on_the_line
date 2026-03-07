# resolver.gd

class_name Resolver extends RefCounted

func resolve_npc_turn(sim: Sim, cid: int) -> void:
	if sim == null or sim.api == null or sim.intent_planner == null:
		return

	sim.intent_planner.run_npc_turn(sim.api, cid)

	if sim.checkpoint_processor != null:
		sim.checkpoint_processor.flush(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, sim, true)


func resolve_player_card(sim: Sim, req: CardPlayRequest, card_executor: CardExecutor) -> bool:
	if sim == null or sim.api == null or card_executor == null:
		return false

	var ok := card_executor.play_card(sim.api, req)

	if sim.checkpoint_processor != null:
		sim.checkpoint_processor.flush(CheckpointProcessor.Kind.AFTER_CARD, sim, true)

	return ok


func resolve_arcana_proc(sim: Sim, proc: int, arcana_resolver: ArcanaResolver) -> void:
	if sim == null or sim.api == null or arcana_resolver == null:
		return

	arcana_resolver.run_proc(proc)

	if sim.checkpoint_processor != null:
		sim.checkpoint_processor.flush(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, sim, true)
	
