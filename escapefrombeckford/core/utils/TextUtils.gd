# res://core/utils/TextUtils.gd
class_name TextUtils

static func count_placeholders(text: String) -> int:
	return text.count("%s")

static func has_placeholders(text: String) -> bool:
	return text.contains("%s")

static func percent_to_symbol(text: String) -> String:
	return text.replace("percent", "%")

static func end_with_period(text: String) -> String:
	if !text.ends_with("."):
		text += "."
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

		var total_slots := count_placeholders(text)
		if total_slots <= 0:
			break

		var values := _description_values_for_action(action, card_data, api)
		if values.is_empty():
			continue

		var args: Array = []
		var apply_n := mini(values.size(), total_slots)
		for i in range(apply_n):
			args.append(values[i])

		for _i in range(total_slots - apply_n):
			args.append("%s")

		text = text % args

	text = text.replace("{percent}", "%")
	text = percent_to_symbol(text)
	return end_with_period(text)

static func _description_values_for_action(
	action: CardAction,
	card_data: CardData = null,
	api: SimBattleAPI = null
) -> Array:
	if action == null:
		return []

	var explicit_values := action.get_description_values(CardActionContext.new())
	if !explicit_values.is_empty():
		return explicit_values

	if action is SummonAction:
		var summon_data := (action as SummonAction).get_preview_summon_data()
		if summon_data != null:
			var summon_ap := int(summon_data.ap)
			var summon_max_health := int(summon_data.max_health)
			if api != null and card_data != null:
				var card_uid := String(card_data.uid)
				if !card_uid.is_empty():
					summon_ap += int(api.get_summon_card_ap_bonus(card_uid))
					summon_max_health += int(api.get_summon_card_max_health_bonus(card_uid))
			return [summon_ap, summon_max_health, String(summon_data.name)]

	if action is HealAction:
		var heal_action := action as HealAction
		if int(heal_action.flat_amount) != 0:
			return [int(heal_action.flat_amount)]
		if !is_zero_approx(float(heal_action.of_total)):
			return [floori(float(heal_action.of_total) * 100.0)]
		if !is_zero_approx(float(heal_action.of_missing)):
			return [floori(float(heal_action.of_missing) * 100.0)]

	if action is DrawAction:
		return [int((action as DrawAction).base_draw)]

	if _has_property(action, "duration"):
		return [int(action.get("duration"))]
	if _has_property(action, "base_damage"):
		return [int(action.get("base_damage"))]
	if _has_property(action, "base_draw"):
		return [int(action.get("base_draw"))]

	return []

static func _has_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false
	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true
	return false
