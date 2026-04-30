class_name MasteryStatus extends Status

const ID := &"mastery"

func get_id() -> StringName:
	return ID


func contributes_modifier() -> bool:
	return true


func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]


func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if ctx == null:
		return []

	var completed_rounds := 0
	if ctx.api != null and ctx.api.state != null:
		var owner := ctx.api.state.get_unit(int(ctx.owner_id))
		if owner != null:
			completed_rounds = maxi(0, int(owner.completed_rounds_lived))

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.flat_value = maxi(0, int(ctx.stacks)) * completed_rounds
	token.mult_value = 0.0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]


func get_tooltip(stacks: int = 0) -> String:
	return "Mastery: for each round survived, deal +%s damage." % stacks
