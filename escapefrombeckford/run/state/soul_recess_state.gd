class_name SoulRecessState extends Resource

@export var unlocked_slot_count: int = 1
@export var slot_souls: Array[CardSnapshot] = []
@export var attuned_souls: Array[CardSnapshot] = []
@export var selected_starting_soul_uid: String = ""


func get_selected_starting_soul_snapshot() -> CardSnapshot:
	if selected_starting_soul_uid.is_empty():
		return null
	return get_attuned_soul_snapshot(selected_starting_soul_uid)


func get_attuned_soul_snapshot(uid: String) -> CardSnapshot:
	if uid.is_empty():
		return null
	for snapshot in attuned_souls:
		if snapshot == null or snapshot.card == null:
			continue
		snapshot.card.ensure_uid()
		if String(snapshot.card.uid) == uid:
			return snapshot
	return null
