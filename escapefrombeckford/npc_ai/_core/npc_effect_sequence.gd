# npc_effect_sequence.gd
class_name NPCEffectSequence extends Resource

func execute(_ctx: NPCAIContext) -> void:
	push_error("Must be implemented")

func realizes_pending_statuses() -> bool:
	return false

func is_sequence_executable(ctx: NPCAIContext) -> bool:
	if ctx == null or ctx.params == null:
		return true
	return bool(ctx.params.get(Keys.SEQUENCE_EXECUTABLE, true))
