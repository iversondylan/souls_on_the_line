# pressure_barrier.gd

class_name PressureBarrier extends Status

const ID = &"pressure_barrier"

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
	token.flat_value = -ctx.intensity
	token.mult_value = 0.0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]
	
func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Pressure Barrier: take %s reduced damage from each strike." % intensity
