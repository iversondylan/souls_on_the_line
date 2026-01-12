# aura.gd
class_name Aura extends Status

const AURA_SECONDARY_FLAG = "aura_secondary"

const AURA_ALLIES := "aura_allies"
const AURA_ENEMIES := "aura_enemies"

enum AuraType {ALLIES, ENEMIES}
@export var aura_type: AuraType

# In modifier tokens...
# Scope answers “who is eligible at all.”
# Tags answer “how eligibility is routed.”
# Effect intent		scope				tags		
# Type				ModifierToken.Scope	ModifierToken.tags
# Everyone			GLOBAL				none
# Only self			SELF				none
# Aura (allies)		TARGET				AURA_SECONDARY_FLAG, AURA_ALLIES
# Aura (enemies)	TARGET				AURA_SECONDARY_FLAG, AURA_ENEMIES
# Explicit target	TARGET				none

func get_modifier_tokens() -> Array[ModifierToken]:
	return []

func contributes_modifier() -> bool:
	return false

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return []
