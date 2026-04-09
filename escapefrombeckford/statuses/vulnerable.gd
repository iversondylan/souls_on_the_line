# vulnerable.gd

class_name VulnerableStatus extends Status

const ID := &"vulnerable"
const MULT_VALUE := 0.5

func get_id() -> StringName:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_TAKEN]

func get_max_intensity() -> int:
	return 1

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if !ctx:
		return []
	if expiration_policy == Status.ExpirationPolicy.DURATION and ctx.duration <= 0:
		return []

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_TAKEN
	token.mult_value = MULT_VALUE
	token.flat_value = 0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.priority = 0
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]

func get_tooltip(_intensity: int = 0, duration: int = 0) -> String:
	if duration == 1:
		return "Vulnerable: takes %s%% more damage for 1 turn. Ticks down at the end of this unit's turn." % floori(MULT_VALUE * 100)
	return "Vulnerable: takes %s%% more damage for %s turns. Ticks down at the end of this unit's turn." % [floori(MULT_VALUE * 100), duration]
