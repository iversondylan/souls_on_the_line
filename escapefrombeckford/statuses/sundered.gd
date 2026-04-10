# sundered.gd

class_name SunderedStatus extends Status

const ID := &"sundered"

func get_id() -> StringName:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_TAKEN]

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if !ctx:
		return []

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_TAKEN
	token.mult_value = 0.01 * float(ctx.intensity)
	token.flat_value = 0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.priority = 0
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Sundered: take %s%% more damage. Clears at the end of this unit's group turn." % intensity
