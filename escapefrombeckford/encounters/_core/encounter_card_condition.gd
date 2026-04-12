
class_name EncounterCardCondition extends EncounterCondition

@export var card_id: StringName = &""
@export var card_uid: StringName = &""
@export var card_proto_path: String = ""

func evaluate_match(ctx: EncounterRuleContext) -> bool:
	if ctx == null:
		return false
	if card_id != &"" and ctx.get_card_id() != card_id:
		return false
	if card_uid != &"" and ctx.get_card_uid() != card_uid:
		return false
	if !card_proto_path.is_empty() and ctx.get_card_proto_path() != card_proto_path:
		return false
	return card_id != &"" or card_uid != &"" or !card_proto_path.is_empty()
