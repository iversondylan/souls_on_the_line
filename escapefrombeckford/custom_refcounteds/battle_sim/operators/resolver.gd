# resolver.gd

class_name Resolver extends RefCounted

var action_executor: ActionExecutor

func _ensure_action_executor() -> ActionExecutor:
	if action_executor == null:
		action_executor = ActionExecutor.new()
	return action_executor

func resolve_npc_turn(sim: Sim, cid: int) -> void:
	if sim == null or sim.api == null:
		return
	_ensure_action_executor().execute_npc_turn(sim, cid)

func resolve_player_card(sim: Sim, req: CardPlayRequest, card_executor: CardExecutor) -> bool:
	if sim == null or sim.api == null or card_executor == null:
		return false
	return card_executor.play_card(sim.api, req)

func resolve_arcana_proc(sim: Sim, proc: int, arcana_resolver: ArcanaResolver) -> void:
	if sim == null or sim.api == null or arcana_resolver == null:
		return
	arcana_resolver.run_proc(proc)
