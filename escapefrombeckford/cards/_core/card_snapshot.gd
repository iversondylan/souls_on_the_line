class_name CardSnapshot extends Resource

@export var template_hint_path: String = ""
@export var card: CardData


static func from_card(source_card: CardData) -> CardSnapshot:
	if source_card == null:
		return null
	var snapshot := CardSnapshot.new()
	snapshot.template_hint_path = String(source_card.base_proto_path if source_card.base_proto_path != "" else source_card.resource_path)
	snapshot.card = source_card.duplicate(true) as CardData
	if snapshot.card != null:
		snapshot.card.base_proto_path = snapshot.template_hint_path
		snapshot.card.ensure_uid()
	return snapshot


func instantiate_card() -> CardData:
	if card == null:
		return null
	var restored := card.make_runtime_instance()
	if restored == null:
		return null
	if restored.base_proto_path == "":
		restored.base_proto_path = template_hint_path
	restored.ensure_uid()
	return restored
