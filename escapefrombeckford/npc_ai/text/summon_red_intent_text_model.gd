# summon_red_intent_text_model.gd
# red in the title denotes: this unit's attack damage shall equal its
# combatant_data.apr
# for this to work, that unit must have an attack package with MaxManaRedDamageModel
# whose base damage is 0 and mana scaling is 1.0

class_name SummonRedIntentTextModel
extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if !ctx:
		return "error"
	
	# NOTE: requires Keys.SUMMON_DATA to be set by a ParamModel, but defaults safely.
	var fallback: CombatantData = load(Keys.DEFAULT_SUMMON_DATA_PATH)
	var data: CombatantData = ctx.params.get(Keys.SUMMON_DATA, fallback)
	
	if !data:
		return "error"
	
	var red := int(data.apr)
	var hp := int(data.max_health)
	
	if red < 0 or hp <= 0:
		return "error"
	
	return "%s/%s" % [red, hp]

func get_text_sim(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"

	var fallback: CombatantData = load(Keys.DEFAULT_SUMMON_DATA_PATH)
	var data: CombatantData = _param_v(ctx, Keys.SUMMON_DATA, fallback)

	if data == null:
		return "error"

	var red := int(data.apr)
	var hp := int(data.max_health)

	if red < 0 or hp <= 0:
		return "error"

	return "%s/%s" % [red, hp]
