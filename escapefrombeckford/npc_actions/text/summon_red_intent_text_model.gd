# summon_red_intent_text_model.gd
# red in the title denotes: this unit's attack damage shall equal its
# combatant_data.max_mana_red
# for this to work, that unit must have an attack package with MaxManaRedDamageModel
# whose base damage is 0 and mana scaling is 1.0

class_name SummonRedIntentTextModel
extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if !ctx:
		return "error"

	# NOTE: requires NPCKeys.SUMMON_DATA to be set by a ParamModel, but defaults safely.
	var fallback: CombatantData = SummonEffect.DEFAULT_SUMMON_DATA
	var data: CombatantData = ctx.params.get(NPCKeys.SUMMON_DATA, fallback)

	if !data:
		return "error"

	var red := int(data.max_mana_red)
	var hp := int(data.max_health)

	if red < 0 or hp <= 0:
		return "error"

	return "%s/%s" % [red, hp]
