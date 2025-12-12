class_name EchoedCrueltyStatus extends Aura

const ID := "echoed_cruelty"

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
	token.scope = ModifierToken.Scope.GLOBAL
	token.tags = ["aura"]

	return [token]

func get_tooltip() -> String:
	return "Echoed Cruelty [Aura]: Allies deal %s additional damage." % intensity
