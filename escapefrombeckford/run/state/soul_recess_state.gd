class_name SoulRecessState extends Resource

@export var unlocked_slot_count: int = 2
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


func get_attuned_soul_snapshot_at(slot_index: int) -> CardSnapshot:
	if slot_index < 0 or slot_index >= attuned_souls.size():
		return null
	return attuned_souls[slot_index]


func set_attuned_soul_snapshot(slot_index: int, snapshot: CardSnapshot) -> void:
	if slot_index < 0:
		return
	while attuned_souls.size() <= slot_index:
		attuned_souls.append(null)
	attuned_souls[slot_index] = snapshot
