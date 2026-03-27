# run_deck.gd

class_name RunDeck extends Resource

@export var card_collection: CardPile = CardPile.new() : set = _set_card_collection
@export var id_counter: int = 0


func add_card(card_data: CardData) -> void:
	var new_card := _instantiate_card(card_data)
	if new_card == null:
		return
	new_card.id = id_counter
	new_card.ensure_uid()
	card_collection.add_back(new_card)
	id_counter += 1


func _set_card_collection(card_pile: CardPile) -> void:
	card_collection = CardPile.new()
	id_counter = 0
	if card_pile == null:
		return
	for card_data: CardData in card_pile.cards:
		var new_card := _instantiate_card(card_data)
		if new_card == null:
			continue
		new_card.id = id_counter
		new_card.ensure_uid()
		card_collection.add_back(new_card)
		id_counter += 1


func remove_card(card_id: int) -> void:
	card_collection.erase(card_id)


func _generate_card_id(card_data: CardData) -> int:
	card_data.id = id_counter
	return id_counter


func _instantiate_card(card_data: CardData) -> CardData:
	if card_data == null:
		return null
	var new_card := card_data.duplicate(true) as CardData
	if new_card == null:
		return null
	if new_card.base_proto_path.is_empty():
		new_card.base_proto_path = String(card_data.base_proto_path if !card_data.base_proto_path.is_empty() else card_data.resource_path)
	new_card.uid = ""
	return new_card


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
	id_counter = 0
	for snapshot in snapshots:
		if snapshot == null:
			continue
		var restored := snapshot.instantiate_card()
		if restored == null:
			continue
		restored.id = id_counter
		card_collection.add_back(restored)
		id_counter += 1
