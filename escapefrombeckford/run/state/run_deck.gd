# run_deck.gd

class_name RunDeck extends Resource

const DEFAULT_SOULBOUND_SLOT_COUNT := 5
const DEFAULT_STARTER_SOUL_PATH := "res://cards/souls/SpectralCloneCard/spectral_clone.tres"

@export var card_collection: CardPile = CardPile.new() : set = _set_card_collection
@export var has_soulbound_roster: bool = true
@export var soulbound_slot_count: int = DEFAULT_SOULBOUND_SLOT_COUNT : set = _set_soulbound_slot_count
@export var soulbound_slots: Array = [] : set = _set_soulbound_slots


func add_card(card_data: CardData) -> void:
	add_normal_card(card_data)


func has_soulbound_roster_enabled() -> bool:
	return bool(has_soulbound_roster)


func add_normal_card(card_data: CardData) -> void:
	var new_card := _instantiate_card(card_data, true)
	if new_card == null:
		return
	if new_card.is_soulbound_slot_card() and has_soulbound_roster_enabled():
		push_warning("RunDeck.add_normal_card(): soulbound slot cards must use replace_soulbound_slot().")
		return
	if card_collection == null:
		card_collection = CardPile.new()
	new_card.ensure_uid()
	card_collection.add_back(new_card)


func replace_soulbound_slot(slot_index: int, card_data: CardData) -> bool:
	if !has_soulbound_roster_enabled():
		return false
	if slot_index < 0 or slot_index >= get_soulbound_slot_count():
		return false
	var new_card := _instantiate_card(card_data, true)
	if new_card == null or !new_card.is_soulbound_slot_card():
		return false
	_ensure_soulbound_slot_size()
	soulbound_slots[slot_index] = new_card
	return true


func initialize_soulbound_slots(signature_card: CardData, starter_card: CardData) -> void:
	if !has_soulbound_roster_enabled():
		soulbound_slots.clear()
		return
	var resolved_starter := starter_card
	if resolved_starter == null:
		resolved_starter = _load_default_starter_soul()
	var resolved_signature := _prepare_signature_slot_card(signature_card)
	if resolved_signature == null:
		resolved_signature = _prepare_signature_slot_card(resolved_starter)

	soulbound_slots.clear()
	if resolved_signature != null:
		soulbound_slots.append(resolved_signature)
	while soulbound_slots.size() < get_soulbound_slot_count():
		if resolved_starter == null:
			break
		var starter_copy := _prepare_signature_slot_card(resolved_starter)
		if starter_copy == null:
			break
		soulbound_slots.append(starter_copy)
	_ensure_soulbound_slot_size()


func get_soulbound_slot_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for card_data in soulbound_slots:
		if card_data != null:
			out.append(card_data)
	return out


func get_soulbound_slot_count() -> int:
	return maxi(int(soulbound_slot_count), 1)


func configure_soulbound_slot_count(new_count: int, starter_card: CardData = null, expected_signature_card: CardData = null) -> void:
	soulbound_slot_count = int(new_count)
	normalize_cards(starter_card, expected_signature_card)


func build_battle_card_collection() -> CardPile:
	var pile := CardPile.new()
	if card_collection != null:
		for card_data in card_collection.cards:
			if card_data == null:
				continue
			pile.add_back(card_data)
	for card_data in soulbound_slots:
		if card_data == null:
			continue
		pile.add_back(card_data)
	return pile


func build_collection_view_card_pile() -> CardPile:
	var pile := CardPile.new()
	for card_data in soulbound_slots:
		if card_data == null:
			continue
		pile.add_back(card_data)
	if card_collection != null:
		for card_data in card_collection.cards:
			if card_data == null:
				continue
			pile.add_back(card_data)
	return pile


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


func _set_soulbound_slot_count(new_count: int) -> void:
	soulbound_slot_count = maxi(int(new_count), 1)
	_ensure_soulbound_slot_size()


func _set_soulbound_slots(cards: Array) -> void:
	soulbound_slots = []
	for card_data in cards:
		var new_card := _instantiate_card(card_data, false)
		if new_card == null:
			continue
		new_card.ensure_uid()
		soulbound_slots.append(new_card)
	_ensure_soulbound_slot_size()


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


func normalize_cards(starter_card: CardData = null, expected_signature_card: CardData = null) -> void:
	if card_collection == null:
		card_collection = CardPile.new()
	var normalized_collection := CardPile.new()
	var normalized_slots: Array[CardData] = []
	var seen_uids := {}
	if !has_soulbound_roster_enabled():
		for card_data in soulbound_slots:
			var migrated_slot_card := _normalize_runtime_card(card_data, seen_uids)
			if migrated_slot_card == null:
				continue
			normalized_collection.add_back(migrated_slot_card)
		for card_data in card_collection.cards:
			var migrated_collection_card := _normalize_runtime_card(card_data, seen_uids)
			if migrated_collection_card == null:
				continue
			normalized_collection.add_back(migrated_collection_card)
		card_collection = normalized_collection
		soulbound_slots.clear()
		_ensure_soulbound_slot_size()
		return
	var starter_fallback := starter_card
	if starter_fallback == null:
		starter_fallback = _find_starter_soul_card(soulbound_slots)

	for index in range(soulbound_slots.size()):
		var card_data: CardData = soulbound_slots[index] as CardData
		var new_card := _normalize_runtime_card(card_data, seen_uids)
		if index == 0 and expected_signature_card != null:
			var normalized_signature := _normalize_expected_signature_card(card_data, expected_signature_card, seen_uids)
			if normalized_signature != null:
				new_card = normalized_signature
		if new_card == null or !new_card.is_soulbound_slot_card():
			continue
		if starter_fallback == null and bool(new_card.starter_card):
			starter_fallback = new_card
		if normalized_slots.size() < get_soulbound_slot_count():
			normalized_slots.append(new_card)

	for card_data in card_collection.cards:
		var new_card := _normalize_runtime_card(card_data, seen_uids)
		if new_card == null:
			continue
		normalized_collection.add_back(new_card)

	if starter_fallback == null:
		starter_fallback = _load_default_starter_soul()
	while normalized_slots.size() < get_soulbound_slot_count() and starter_fallback != null:
		var starter_copy := _prepare_signature_slot_card(starter_fallback)
		if starter_copy == null:
			break
		_ensure_unique_uid(starter_copy, seen_uids)
		normalized_slots.append(starter_copy)

	if expected_signature_card != null:
		if normalized_slots.is_empty() or !_cards_match_signature_identity(normalized_slots[0], expected_signature_card):
			push_warning("RunDeck.normalize_cards(): slot 0 was replaced during new-run normalization; starter fallback was used instead of the selected signature soul.")

	card_collection = normalized_collection
	soulbound_slots = normalized_slots
	_ensure_soulbound_slot_size()


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


func _normalize_runtime_card(card_data: CardData, seen_uids: Dictionary) -> CardData:
	var new_card := _instantiate_card(card_data, false)
	if new_card == null:
		return null
	_ensure_unique_uid(new_card, seen_uids)
	return new_card


func _normalize_expected_signature_card(card_data: CardData, expected_signature_card: CardData, seen_uids: Dictionary) -> CardData:
	var normalized := _normalize_runtime_card(card_data, seen_uids)
	if normalized != null and normalized.is_soulbound_slot_card() and _cards_match_signature_identity(normalized, expected_signature_card):
		return normalized
	if normalized != null and !normalized.is_soulbound_slot_card():
		push_warning("RunDeck.normalize_cards(): deserialized signature soul in slot 0 failed soulbound-slot classification; attempting proto recovery.")
	var recovered := _recover_soulbound_slot_card(expected_signature_card, true)
	if recovered != null and recovered.is_soulbound_slot_card():
		_ensure_unique_uid(recovered, seen_uids)
		return recovered
	push_warning("RunDeck.normalize_cards(): failed to recover selected signature soul for slot 0; starter fallback will be used.")
	return null


func _ensure_unique_uid(card_data: CardData, seen_uids: Dictionary) -> void:
	card_data.ensure_uid()
	if seen_uids.has(card_data.uid):
		card_data.uid = ""
		card_data.ensure_uid()
	seen_uids[card_data.uid] = true


func _prepare_signature_slot_card(card_data: CardData) -> CardData:
	if card_data == null:
		return null
	var prepared := _instantiate_card(card_data, true)
	if prepared != null and prepared.is_soulbound_slot_card():
		return prepared
	if prepared != null:
		push_warning("RunDeck.initialize_soulbound_slots(): signature soul failed soulbound-slot classification after instantiation; attempting proto recovery.")
	var recovered := _recover_soulbound_slot_card(card_data, true)
	if recovered != null and recovered.is_soulbound_slot_card():
		return recovered
	push_warning("RunDeck.initialize_soulbound_slots(): unable to preserve selected signature soul; falling back to starter soul.")
	return null


func _recover_soulbound_slot_card(card_data: CardData, regenerate_uid: bool) -> CardData:
	if card_data == null:
		return null
	var proto_path := String(card_data.base_proto_path if !card_data.base_proto_path.is_empty() else card_data.resource_path)
	if proto_path.is_empty():
		return null
	var proto := load(proto_path) as CardData
	if proto == null:
		return null
	var recovered := proto.duplicate(true) as CardData
	if recovered == null:
		return null
	CardData._copy_runtime_overrides(card_data, recovered)
	if recovered.base_proto_path.is_empty():
		recovered.base_proto_path = proto_path
	if regenerate_uid:
		recovered.uid = ""
	recovered.ensure_id()
	recovered.ensure_uid()
	return recovered


func _cards_match_signature_identity(actual: CardData, expected: CardData) -> bool:
	if actual == null or expected == null:
		return false
	var actual_data := CardSnapshot.serialize_card_data(actual)
	var expected_data := CardSnapshot.serialize_card_data(expected)
	actual_data.erase("uid")
	expected_data.erase("uid")
	return actual_data == expected_data


func _ensure_soulbound_slot_size() -> void:
	if !has_soulbound_roster_enabled():
		soulbound_slots.clear()
		return
	while soulbound_slots.size() < get_soulbound_slot_count():
		soulbound_slots.append(null)
	while soulbound_slots.size() > get_soulbound_slot_count():
		soulbound_slots.remove_at(soulbound_slots.size() - 1)


func _find_starter_soul_card(cards: Array) -> CardData:
	for card_value in cards:
		var card_data := card_value as CardData
		if card_data == null:
			continue
		if card_data.is_soulbound_slot_card() and bool(card_data.starter_card):
			return card_data
	return null


func _load_default_starter_soul() -> CardData:
	return load(DEFAULT_STARTER_SOUL_PATH) as CardData
