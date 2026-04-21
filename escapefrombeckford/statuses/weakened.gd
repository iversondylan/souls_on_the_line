# weakened.gd

class_name WeakenedStatus extends Status

const ID := &"weakened"
const MULT_VALUE := 0.5

func get_id() -> StringName:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func get_max_stacks() -> int:
	return 1

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if !ctx:
		return []
	
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.mult_value = -MULT_VALUE
	token.flat_value = 0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.priority = 0
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]

func get_tooltip(stacks: int = 0) -> String:
	if stacks == 1:
		return "Weakened: deal %s%% less damage for 1 turn. Ticks down at end of turn." % floori(MULT_VALUE * 100)
	return "Weakened: deal %s%% less damage for %s turns. Ticks down at end of turn." % [floori(MULT_VALUE * 100), stacks]
