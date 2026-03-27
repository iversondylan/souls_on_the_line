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

		var values := _description_values_for_action(action)
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

static func _description_values_for_action(action: CardAction) -> Array:
	if action == null:
		return []

	var script_path := ""
	var script_ref : Script = action.get_script()
	if script_ref != null:
		script_path = String(script_ref.resource_path)

	if action.has_method("get_description_values"):
		var explicit_values = action.call("get_description_values", CardActionContext.new())
		if explicit_values is Array and !explicit_values.is_empty():
			return explicit_values

	if action is SummonAction:
		var summon_data := (action as SummonAction).get_preview_summon_data()
		if summon_data != null:
			return [int(summon_data.apr), int(summon_data.max_health), String(summon_data.name)]

	if action is StatusOnSummonedAction:
		var status_action := action as StatusOnSummonedAction
		if status_action.status != null and _has_property(status_action.status, "max_health_per_strike"):
			return [int(status_action.status.max_health_per_strike)]

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

	if script_path.ends_with("cards/PinpointCard/pinpoint_action.gd"):
		return [floori(float(PinpointStatus.MULT_VALUE) * 100.0), int(action.get("duration"))]

	if script_path.ends_with("cards/SuperchargeCard/amplify_action.gd"):
		return [floori(float(AmplifyStatus.MULT_VALUE) * 100.0), int(action.get("amplify_duration"))]

	if _has_property(action, "n_armor"):
		return [int(action.get("n_armor"))]
	if _has_property(action, "pressure_barrier_intensity"):
		return [int(action.get("pressure_barrier_intensity"))]
	if _has_property(action, "cruel_dominion_intensity"):
		return [int(action.get("cruel_dominion_intensity"))]
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
