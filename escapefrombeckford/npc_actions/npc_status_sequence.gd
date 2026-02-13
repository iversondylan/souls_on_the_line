# npc_status_sequence.gd
class_name NPCStatusSequence
extends NPCEffectSequence

func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	# Always finish
	if !ctx:
		on_done.call()
		return

	# Strictly stateless during forecast
	if bool(ctx.forecast):
		on_done.call()
		return

	# Resolve API
	var api: BattleAPI = ctx.api
	if !api and ctx.battle_scene:
		api = ctx.battle_scene.api
	if !api:
		on_done.call()
		return

	# Resolve target combat_id (self)
	var target_id := 0
	if ctx.combatant:
		target_id = int(ctx.combatant.combat_id)
	elif ctx.combatant_data:
		target_id = int(ctx.combatant_data.combat_id)

	if target_id <= 0:
		on_done.call()
		return

	# Resolve status prototype
	var status_res : Status = ctx.params.get(NPCKeys.STATUS_SCENE, null)
	if !status_res or !(status_res is Status):
		on_done.call()
		return

	# Duplicate so we never mutate the authored resource
	var status: Status = (status_res as Status).duplicate()

	# Optional numeric overrides
	if ctx.params.has(NPCKeys.STATUS_INTENSITY):
		status.intensity = int(ctx.params[NPCKeys.STATUS_INTENSITY])

	if ctx.params.has(NPCKeys.STATUS_DURATION):
		status.duration = int(ctx.params[NPCKeys.STATUS_DURATION])

	# Build context + apply via API
	var sc := StatusContext.new()
	sc.target_id = target_id
	# Optional: source_id (self) if you want ownership semantics later
	sc.source_id = target_id
	sc.status = status

	api.apply_status(sc)

	on_done.call()
