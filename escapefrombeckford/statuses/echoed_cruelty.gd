# echoed_cruelty.gd

class_name EchoedCrueltyStatus extends Aura

const ID := &"echoed_cruelty"

func get_id() -> StringName:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if !ctx:
		return []

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.flat_value = ctx.intensity
	token.mult_value = 0.0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.TARGET
	token.tags = [
		Aura.AURA_SECONDARY_FLAG,
		Aura.AURA_ALLIES
	]

	Status.set_token_owner(token, ctx)
	return [token]


func get_tooltip() -> String:
	return "Echoed Cruelty [Aura]: Allies deal %s additional damage." % intensity
