# mana_context.gd
class_name ManaContext extends RefCounted

enum Mode {
	SET_MANA,
	SET_MAX_MANA,
	GAIN_MANA,
	REFRESH_FOR_GROUP_TURN,
	SPEND_FOR_CARD
}

var source_id: int = 0
var mode: int = Mode.SET_MANA
var reason: String = ""

var amount: int = 0
var new_mana: int = 0
var new_max_mana: int = 0
var refill: bool = false
var group_index: int = -1

var card_uid: String = ""
var card_name: String = ""

var before_mana: int = 0
var after_mana: int = 0
var before_max_mana: int = 0
var after_max_mana: int = 0
var changed: bool = false
