# summon_ap_intent_tooltip_text_model.gd
# ap in the title denotes: this unit's attack damage shall equal its
# combatant_data.ap
# for this to work, that unit must have an attack package with MaxApDamageModel
# whose base damage is 0 and mana scaling is 1.0

class_name SummonApIntentTooltipTextModel
extends TextModel

const DEFAULT_TEXT_TEMPLATE := "[b]{action_name}[/b]: summon {count} {ap}|{hp} {summon_name}."

@export_multiline var text_template: String = DEFAULT_TEXT_TEMPLATE

func _fallback_summon_data(ctx: NPCAIContext) -> CombatantData:
	var path := String(_param_v(ctx, Keys.DEFAULT_SUMMON_DATA_PATH, ""))
	if path.is_empty():
		return null
	var data := load(path)
	return data if data is CombatantData else null


func _resolve_text_template() -> String:
	if text_template.strip_edges().is_empty():
		return DEFAULT_TEXT_TEMPLATE
	return text_template


func _apply_legacy_stat_formatting(template: String, ap: int, hp: int) -> String:
	var placeholder_count := template.count("%s")
	if placeholder_count >= 2:
		return template % [ap, hp]
	if placeholder_count == 1:
		return template % ("%s/|%s" % [ap, hp])
	return template


func _format_count_token(count: int) -> String:
	match count:
		1:
			return "a"
		2:
			return "two"
		3:
			return "three"
		4:
			return "four"
		_:
			return str(count)


func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"

	var fallback := _fallback_summon_data(ctx)
	var data: CombatantData = _param_v(ctx, Keys.SUMMON_DATA, fallback)

	if data == null:
		return "error"

	var ap := int(data.ap)
	var hp := int(data.max_health)
	var count := maxi(_param_i(ctx, Keys.SUMMON_COUNT, 1), 0)
	if ap < 0 or hp <= 0:
		return "error"
	if count <= 0:
		return "error"

	var result := _resolve_text_template()
	result = result.replace("{action_name}", str(ctx.action_name))
	result = result.replace("{summon_name}", str(data.name))
	result = result.replace("{count}", _format_count_token(count))
	result = result.replace("{summon_count}", str(count))
	result = result.replace("{count_number}", str(count))
	result = result.replace("{ap}", str(ap))
	result = result.replace("{red}", str(ap))
	result = result.replace("{hp}", str(hp))
	return _apply_legacy_stat_formatting(result, ap, hp)
