# npc_effect_sequence.gd
class_name NPCEffectSequence extends Resource

func execute(_ctx: NPCAIContext) -> void:
	push_error("Must be implemented")

func realizes_pending_statuses() -> bool:
	return false
