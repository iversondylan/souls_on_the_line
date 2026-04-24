# Generic shared base for card-owned interaction contexts.
class_name EscrowCardInteractionContext extends InteractionContext

var card: UsableCard
var card_ctx: CardContext
var action_index: int = -1

func get_interaction_kind() -> StringName:
	return &"card"

func _build_gate_payload(extra_payload: Dictionary = {}) -> Dictionary:
	var payload := extra_payload.duplicate(true)
	payload[Keys.INTERACTION_KIND] = String(get_interaction_kind())
	return payload

func _build_interaction_gate_request(
	kind: int,
	target_ids: PackedInt32Array = PackedInt32Array(),
	insert_index: int = -1,
	payload: Dictionary = {}
) -> EncounterGateRequest:
	var gate_request := EncounterGateRequest.new()
	gate_request.kind = int(kind)
	gate_request.action_index = int(action_index)
	gate_request.target_ids = target_ids.duplicate()
	gate_request.insert_index = int(insert_index)
	gate_request.payload = _build_gate_payload(payload)
	if card_ctx != null and card_ctx.card_data != null:
		card_ctx.card_data.ensure_uid()
		gate_request.card_uid = StringName(String(card_ctx.card_data.uid))
	return gate_request

func _evaluate_interaction_gate(
	kind: int,
	target_ids: PackedInt32Array = PackedInt32Array(),
	insert_index: int = -1,
	payload: Dictionary = {}
) -> bool:
	if handler == null:
		return true
	var gate_request := _build_interaction_gate_request(kind, target_ids, insert_index, payload)
	var cancel_ctx: CardContext = card_ctx if int(kind) == int(EncounterGateRequest.Kind.OPEN_CARD_INTERACTION) else null
	var cancel_action_index := int(action_index) if int(kind) == int(EncounterGateRequest.Kind.OPEN_CARD_INTERACTION) else -1
	return handler.evaluate_interaction_gate(gate_request, cancel_ctx, cancel_action_index)
