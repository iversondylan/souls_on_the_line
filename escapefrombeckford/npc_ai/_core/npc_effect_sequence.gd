# npc_effect_sequence.gd
class_name NPCEffectSequence extends Resource

func execute(_ctx: NPCAIContext, _on_done: Callable) -> void:
	push_error("Must be implemented")

func execute_sim(ctx: NPCAIContext) -> void:
	push_error("Must be implemented")
