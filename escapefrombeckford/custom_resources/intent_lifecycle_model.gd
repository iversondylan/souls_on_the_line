# intent_lifecycle_model.gd

class_name IntentLifecycleModel extends Resource

## Models that react to an NPCAction becoming or ceasing to be the planned intent.
## These are for "intent-time" effects (buffs active during telegraph, channeling, posture, etc.)

## Called when this action becomes the planned intent
## every time!
func on_intent_chosen(_ctx: NPCAIContext) -> void:
	pass
func on_intent_chosen_sim(_ctx: NPCAIContext) -> void:
	pass
## Called when this action stops being the planned intent
## due to reprioritization or interruption via plan_next_intent(allow_hooks = true)
func on_intent_canceled(_ctx: NPCAIContext) -> void:
	pass
func on_intent_canceled_sim(_ctx: NPCAIContext) -> void:
	pass
func on_opposing_group_start(_ctx: NPCAIContext) -> void:
	pass
func on_opposing_group_start_sim(_ctx: NPCAIContext) -> void:
	pass
func on_my_group_end(_ctx: NPCAIContext) -> void:
	pass
func on_my_group_end_sim(_ctx: NPCAIContext) -> void:
	pass
func on_ability_started(_ctx: NPCAIContext) -> void:
	pass
func on_ability_started_sim(_ctx: NPCAIContext) -> void:
	pass
