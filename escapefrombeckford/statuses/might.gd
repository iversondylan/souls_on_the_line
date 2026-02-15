# might.gd

class_name Might extends Status

const ID = &"might"

func get_id() -> String:
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
	token.scope = ModifierToken.Scope.SELF
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]
	
func get_tooltip() -> String:
	var base_tooltip: String = "Might: Deals %s additional damage."
	return base_tooltip % intensity
