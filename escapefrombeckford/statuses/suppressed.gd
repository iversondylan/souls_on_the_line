# suppressed.gd

class_name SuppressedStatus extends Status

const ID := &"suppressed"

func get_id() -> StringName:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func get_max_intensity() -> int:
	return 100

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if !ctx:
		return []

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.mult_value = -0.01 * float(ctx.intensity)
	token.flat_value = 0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.priority = 0
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Suppressed: deals %s%% less damage. Clears at the end of this unit's group turn." % intensity
