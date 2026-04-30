class_name RemovalRecord extends RefCounted

var target_id: int = 0
var killer_id: int = 0
var group_index: int = -1
var removal_type: int = Removal.Type.DEATH
var reason: String = ""
var round_number: int = 1
var group_turn_number: int = 0
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""
var completed_group_turns_lived: int = 0

func clone() -> RemovalRecord:
	var c := RemovalRecord.new()
	c.target_id = target_id
	c.killer_id = killer_id
	c.group_index = group_index
	c.removal_type = removal_type
	c.reason = reason
	c.round_number = round_number
	c.group_turn_number = group_turn_number
	c.origin_card_uid = origin_card_uid
	c.origin_arcanum_id = origin_arcanum_id
	c.completed_group_turns_lived = completed_group_turns_lived
	return c
