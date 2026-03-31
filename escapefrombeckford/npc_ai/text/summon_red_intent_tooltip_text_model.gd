# summon_red_intent_tooltip_text_model.gd
# red in the title denotes: this unit's attack damage shall equal its
# combatant_data.apr
# for this to work, that unit must have an attack package with MaxManaRedDamageModel
# whose base damage is 0 and mana scaling is 1.0

class_name SummonRedIntentTooltipTextModel
extends TextModel

@export_multiline var text_template: String = "[b]Summon Intent[/b] [{summon_name}]: %s/%s unit."

func _fallback_summon_data(ctx: NPCAIContext) -> CombatantData:
	var path := String(_param_v(ctx, Keys.DEFAULT_SUMMON_DATA_PATH, ""))
	if path.is_empty():
		return null
	var data := load(path)
	return data if data is CombatantData else null


func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"

	var fallback := _fallback_summon_data(ctx)
	var data: CombatantData = _param_v(ctx, Keys.SUMMON_DATA, fallback)

	if data == null:
		return "error"

	var red := int(data.apr)
	var hp := int(data.max_health)
	var count := maxi(_param_i(ctx, Keys.SUMMON_COUNT, 1), 0)
	if red < 0 or hp <= 0:
		return "error"
	if count <= 0:
		return "error"

	var result := text_template
	result = result.replace("{summon_name}", String(data.name))
	if count == 1:
		return result % [red, hp]
	return "[b]Summon Intent[/b] [%s]: %s units of %s/%s." % [String(data.name), count, red, hp]
