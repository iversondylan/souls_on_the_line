class_name Might extends Status

#var member_var := 0
const ID = "might"

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func get_modifier_tokens() -> Array[ModifierToken]:
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.flat_value = intensity
	token.mult_value = 0.0
	token.source_id = ID
	token.owner = status_parent
	token.scope = ModifierToken.Scope.SELF
	token.tags = [ID]

	return [token]
	
func get_tooltip() -> String:
	var base_tooltip: String = "Might: Deals %s additional damage."
	return base_tooltip % intensity
