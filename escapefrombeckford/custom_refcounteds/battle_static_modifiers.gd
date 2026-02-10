# battle_static_modifiers.gd

class_name BattleStaticModifiers extends RefCounted

# target_combat_id -> Array[ModifierToken] (id-based tokens, no Node refs)
var tokens_by_target_id: Dictionary = {}

func set_tokens_for_target(target_id: int, tokens: Array[ModifierToken]) -> void:
	tokens_by_target_id[target_id] = tokens

func get_tokens_for_target(target_id: int) -> Array[ModifierToken]:
	return tokens_by_target_id.get(target_id, [])
