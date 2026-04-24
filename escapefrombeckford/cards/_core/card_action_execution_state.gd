# card_action_execution_state.gd

class_name CardActionExecutionState extends RefCounted

enum State {
	PENDING,
	WAITING_PREFLIGHT,
	WAITING_ASYNC_RESOLUTION,
	EXECUTED,
	SKIPPED,
	CANCELED
}

var action_index: int = -1
var action: CardAction
var preflight_interaction_mode: int = CardAction.InteractionMode.NONE
var preflight_complete: bool = true
var state: int = State.PENDING
