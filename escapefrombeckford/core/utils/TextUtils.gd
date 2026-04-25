# res://core/utils/TextUtils.gd
class_name TextUtils

static func count_placeholders(text: String) -> int:
	return text.count("%s")

static func has_placeholders(text: String) -> bool:
	return text.contains("%s")

static func percent_to_symbol(text: String) -> String:
	return text.replace("percent", "%")

static func finalize_description_text(text: String) -> String:
	text = text.strip_edges()
	return text

static func build_card_description(card_data: CardData) -> String:
	return _build_card_description_internal(card_data, null)

static func build_battle_card_description(card_data: CardData, api: SimBattleAPI) -> String:
	return _build_card_description_internal(card_data, api)

static func _build_card_description_internal(card_data: CardData, api: SimBattleAPI) -> String:
	if card_data == null:
		return ""

	var text := String(card_data.description)
	if text == "":
		return ""

	for action in card_data.actions:
		if action == null:
			continue

		var value := _description_value_for_action(action, card_data, api)
		if has_placeholders(text):
			text = _replace_next_placeholder(text, value)
		else:
			text += action.get_extra_description(CardActionContext.new())

	text = text.replace("{percent}", "%")
	text = percent_to_symbol(text)
	return finalize_description_text(text)

static func _description_value_for_action(
	action: CardAction,
	card_data: CardData = null,
	api: SimBattleAPI = null
) -> String:
	if action == null:
		return ""

	return action.get_description_value(CardActionContext.new())

static func _replace_next_placeholder(text: String, replacement: String) -> String:
	var slot_index := text.find("%s")
	if slot_index == -1:
		return text

	return text.substr(0, slot_index) + replacement + text.substr(slot_index + 2)
