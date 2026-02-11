# npc_status_sequence.gd
class_name NPCStatusSequence
extends NPCEffectSequence

func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	var fighter := ctx.combatant
	if !fighter:
		on_done.call()
		return
	
	var status_res: Resource = ctx.params.get(NPCKeys.STATUS_SCENE)
	if !status_res or !(status_res is Status):
		on_done.call()
		return
	
	# Duplicate to never mutate the .tres
	var status : Status = status_res.duplicate()
	
	# Optional authored parameters
	if ctx.params.has(NPCKeys.STATUS_INTENSITY):
		status.intensity = int(ctx.params[NPCKeys.STATUS_INTENSITY])
	
	if ctx.params.has(NPCKeys.STATUS_DURATION):
		status.duration = int(ctx.params[NPCKeys.STATUS_DURATION])
	
	#if ctx.params.has(NPCKeys.STATUS_STACK_TYPE):
		#status.stack_type = ctx.params[NPCKeys.STATUS_STACK_TYPE]
	#
	#if ctx.params.has(NPCKeys.STATUS_EXPIRATION_POLICY):
		#status.expiration_policy = ctx.params[NPCKeys.STATUS_STACK_TYPE]
	
	# Apply
	var effect := StatusEffect.new()
	effect.targets = [fighter]
	effect.status = status
	effect.execute(BattleAPI.new())
	
	on_done.call()
