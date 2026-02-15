# move_context.gd

class_name MoveContext extends RefCounted

enum MoveType {
	TRAVERSE_PLAYER,
	MOVE_TO_FRONT,
	MOVE_TO_BACK,
	SWAP_WITH_TARGET,
	SWAP_WITH_ADJACENT,
	INSERT_AT_INDEX
}

var move_type: int = MoveType.MOVE_TO_FRONT

var actor: Fighter = null
var actor_id: int = 0

var target: Fighter = null
var target_id: int = 0

# for INSERT_AT_INDEX
var index: int = -1

# turn-queue rule
var can_restore_turn: bool = false
var before_order_ids: Array[int] = []
var after_order_ids: Array[int] = []

# optional
var sound: Sound = null
