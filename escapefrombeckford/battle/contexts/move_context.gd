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

# Initiator of the move: acting unit, card player, or -1 for arcanum-driven moves.
var actor_id: int = 0

# Primary unit being repositioned.
var move_unit_id: int = 0

# Optional swap partner.
var target_id: int = 0

# for INSERT_AT_INDEX
var index: int = -1

# explicit turn-queue instructions
var mover_reenters_queue: bool = false
var grant_turns: PackedInt32Array = PackedInt32Array()
var revoke_turns: PackedInt32Array = PackedInt32Array()
var before_order_ids: PackedInt32Array = PackedInt32Array()
var after_order_ids: PackedInt32Array = PackedInt32Array()

# optional
var sound: Sound = null
var reason: String = ""
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""
