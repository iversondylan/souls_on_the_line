# card_action_execution_state.gd

class_name CardActionExecutionState extends RefCounted

enum State {
	PENDING,
	WAITING_INTERACTION,
	WAITING_ASYNC_RESOLUTION,
	COVERED,
	EXECUTED,
	SKIPPED,
	CANCELED
}

var action_index: int = -1
var action: CardAction
var interaction_mode: int = CardAction.InteractionMode.NONE
var state: int = State.PENDING
