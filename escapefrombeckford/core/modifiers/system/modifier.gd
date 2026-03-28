class_name Modifier

# NOTE:
# This class exists ONLY to define Modifier.Type.
# All modifier logic lives in:
# - ModifierToken
# - ModifierSystem
# - BattleScene / Run routing
#
# This class is intentionally non-functional.

enum Type {
	DMG_DEALT, 
	DMG_TAKEN, 
	CARD_COST, 
	NO_MODIFIER
	}
