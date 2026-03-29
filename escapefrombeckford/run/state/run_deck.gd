# run_deck.gd

class_name RunDeck extends Resource

@export var card_collection: CardPile = CardPile.new() : set = _set_card_collection


func add_card(card_data: CardData) -> void:
	var new_card := _instantiate_card(card_data, true)
	if new_card == null:
		return
	new_card.ensure_uid()
	card_collection.add_back(new_card)


func _set_card_collection(card_pile: CardPile) -> void:
	card_collection = CardPile.new()
	if card_pile == null:
		return
	for card_data: CardData in card_pile.cards:
		var new_card := _instantiate_card(card_data, false)
		if new_card == null:
			continue
		new_card.ensure_uid()
		card_collection.add_back(new_card)


func remove_card(card_uid: String) -> void:
	if card_collection == null or card_uid.is_empty():
		return
	for i in range(card_collection.cards.size() - 1, -1, -1):
		var card := card_collection.cards[i]
		if card != null and card.uid == card_uid:
			card_collection.cards.remove_at(i)
			card_collection.card_pile_size_changed.emit(card_collection.cards.size())
			return


func _instantiate_card(card_data: CardData, regenerate_uid: bool) -> CardData:
	if card_data == null:
		return null
	var new_card := card_data.make_runtime_instance()
	if new_card == null:
		return null
	if new_card.base_proto_path.is_empty():
		new_card.base_proto_path = String(card_data.base_proto_path if !card_data.base_proto_path.is_empty() else card_data.resource_path)
	if regenerate_uid:
		new_card.uid = ""
	return new_card


func normalize_cards() -> void:
	if card_collection == null:
		card_collection = CardPile.new()
		return
	var normalized := CardPile.new()
	var seen_uids := {}
	for card_data in card_collection.cards:
		var new_card := _instantiate_card(card_data, false)
		if new_card == null:
			continue
		new_card.ensure_uid()
		if seen_uids.has(new_card.uid):
			new_card.uid = ""
			new_card.ensure_uid()
		seen_uids[new_card.uid] = true
		normalized.add_back(new_card)
	card_collection = normalized


func serialize_cards() -> Array[CardSnapshot]:
	var snapshots: Array[CardSnapshot] = []
	if card_collection == null:
		return snapshots
	for card in card_collection.cards:
		var snapshot := CardSnapshot.from_card(card)
		if snapshot != null:
			snapshots.append(snapshot)
	return snapshots


func deserialize_cards(snapshots: Array[CardSnapshot]) -> void:
	card_collection = CardPile.new()
	for snapshot in snapshots:
		if snapshot == null:
			continue
		var restored := snapshot.instantiate_card()
		if restored == null:
			continue
		restored.ensure_uid()
		card_collection.add_back(restored)
