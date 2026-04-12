class_name EncounterGateRequest extends RefCounted

enum Kind {
	END_TURN,
	PLAY_CARD,
	OPEN_SUMMON_REPLACE,
	CONFIRM_SUMMON_REPLACE,
	OPEN_SWAP,
	CONFIRM_SWAP,
	OPEN_DISCARD,
	CONFIRM_DISCARD,
}

var kind: int = Kind.PLAY_CARD
var card_id: StringName = &""
var card_uid: StringName = &""
var source_id: int = 0
var target_ids: PackedInt32Array = PackedInt32Array()
var insert_index: int = -1
var action_index: int = -1
var payload: Dictionary = {}
