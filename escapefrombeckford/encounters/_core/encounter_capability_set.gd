class_name EncounterCapabilitySet extends Resource

@export var can_end_turn: bool = true
@export var can_play_cards: bool = true
@export var can_swap: bool = true
@export var can_select_discard: bool = true
@export var presentation_locked: bool = false

@export var allowed_card_uids: PackedStringArray = PackedStringArray()
@export var allowed_target_ids: PackedInt32Array = PackedInt32Array()
@export var allowed_insert_indices: PackedInt32Array = PackedInt32Array()

func clone():
	return duplicate(true)

func allows_card_uid(card_uid: String) -> bool:
	if !can_play_cards:
		return false
	if allowed_card_uids.is_empty():
		return true
	return allowed_card_uids.has(String(card_uid))

func allows_insert_index(insert_index: int) -> bool:
	if insert_index < 0 or allowed_insert_indices.is_empty():
		return true
	return allowed_insert_indices.has(int(insert_index))

func allows_target_ids(target_ids: PackedInt32Array) -> bool:
	if allowed_target_ids.is_empty():
		return true
	for target_id in target_ids:
		if !allowed_target_ids.has(int(target_id)):
			return false
	return true
