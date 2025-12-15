class_name Aura extends Status

const AURA_SECONDARY_FLAG = "aura_secondary"

enum AuraType {ALLIES, ENEMIES}
@export var aura_type: AuraType


#Scope answers “who is eligible at all.”
#Tags answer “how eligibility is routed.”
#Effect intent		scope		tags
#Everyone			GLOBAL		none
#Only self			SELF		none
#Aura (allies)		TARGET		AURA_SECONDARY_FLAG, aura_allies
#Aura (enemies)		TARGET		AURA_SECONDARY_FLAG, aura_enemies
#Explicit target	TARGET		none
func get_modifier_tokens() -> Array[ModifierToken]:
	return []

func contributes_modifier() -> bool:
	return false

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return []
