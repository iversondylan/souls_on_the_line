# summon_ap_intent_text_model.gd
# ap in the title denotes: this unit's attack damage shall equal its
# combatant_data.ap
# for this to work, that unit must have an attack package with MaxApDamageModel
# whose base damage is 0 and mana scaling is 1.0

class_name SummonApIntentTextModel
extends TextModel

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

	var ap := int(data.ap)
	var hp := int(data.max_health)
	var count := maxi(_param_i(ctx, Keys.SUMMON_COUNT, 1), 0)

	if ap < 0 or hp <= 0:
		return "error"
	if count <= 0:
		return "error"
	if count == 1:
		return "%s|%s" % [ap, hp]

	return "%s×%s|%s" % [count, ap, hp]
