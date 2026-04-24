class_name EnergySurgeStatus extends Status

const ID := &"energy_surge"

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
	token.flat_value = int(ctx.stacks)
	token.mult_value = 0.0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.tags = [String(ID)]
	Status.set_token_owner(token, ctx)
	return [token]

func get_tooltip(stacks: int = 0) -> String:
	return "Energy Surge: deal +%s damage. Clears at player turn start." % stacks
