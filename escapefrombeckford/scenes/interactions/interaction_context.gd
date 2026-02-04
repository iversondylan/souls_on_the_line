# interaction_context.gd
class_name InteractionContext
extends RefCounted

var handler: BattleInteractionHandler
func enter() -> void: pass
func exit() -> void: pass
