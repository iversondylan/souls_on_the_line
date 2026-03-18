# resolver.gd

class_name Resolver extends RefCounted

#var action_executor: ActionExecutor


#func _init() -> void:
	#action_executor = ActionExecutor.new()


func resolve_npc_turn(api: SimBattleAPI, cid: int) -> void:
	if api == null:
		return
	#if action_executor == null:
		#action_executor = ActionExecutor.new()

	ActionExecutor.execute_npc_turn(api, cid)


func resolve_player_card(sim: Sim, req: CardPlayRequest) -> bool:

	return CardExecutor.play_card(sim.api, req)


func resolve_arcana_proc(sim: Sim, proc: int, arcana_resolver: ArcanaResolver) -> void:
	if sim == null or sim.api == null or arcana_resolver == null:
		return

	arcana_resolver.run_proc(proc)
