class_name SoulRecessState extends Resource

@export var unlocked_slot_count: int = 2
@export var attuned_souls: Array[CardSnapshot] = []
@export var selected_starting_soul_uid: String = ""


func get_selected_starting_soul_snapshot() -> CardSnapshot:
	if selected_starting_soul_uid.is_empty():
		return null
	return get_attuned_soul_snapshot(selected_starting_soul_uid)


func build_signature_soul_options(starter_soul: CardData) -> Array:
	var options: Array = []
	var starter_card := _instantiate_signature_card(starter_soul)
	if starter_card != null:
		options.append({
			"selection_uid": "",
			"card": starter_card,
		})

	for slot_index in range(maxi(int(unlocked_slot_count), 0)):
		var snapshot := get_attuned_soul_snapshot_at(slot_index)
		if snapshot == null:
			continue
		var card_data := snapshot.instantiate_card()
		if card_data == null:
			continue
		card_data.ensure_uid()
		options.append({
			"selection_uid": String(card_data.uid),
			"card": card_data,
		})
	return options


func resolve_selected_signature_soul_card(selected_uid: String, starter_soul: CardData) -> CardData:
	if selected_uid.is_empty():
		return _instantiate_signature_card(starter_soul)

	var snapshot := get_attuned_soul_snapshot(selected_uid)
	if snapshot != null:
		var card_data := snapshot.instantiate_card()
		if card_data != null:
			card_data.ensure_uid()
			return card_data

	return _instantiate_signature_card(starter_soul)


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


func _instantiate_signature_card(source_card: CardData) -> CardData:
	if source_card == null:
		return null
	var card_data := source_card.make_runtime_instance()
	if card_data == null:
		return null
	card_data.ensure_uid()
	return card_data
