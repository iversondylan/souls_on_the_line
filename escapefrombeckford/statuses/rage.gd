class_name RageStatus extends Status

const ID := &"rage"


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
	token.flat_value = int(ctx.intensity)
	token.mult_value = 0.0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]


func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Rage: deal +%s damage." % intensity
