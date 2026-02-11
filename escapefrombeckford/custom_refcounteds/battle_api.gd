# battle_api.gd
class_name BattleAPI extends RefCounted

# --- Lookup / targeting support (models + effects) ---
func is_alive(combat_id: int) -> bool:
	return false

func get_team(combat_id: int) -> int:
	return -1

func get_targets_for_attack_sequence(ctx) -> Array:
	return []

# --- Core resolution verbs ---
func apply_damage_amount(ctx: DamageContext, amount: int) -> Dictionary:
	return {}

func resolve_damage(ctx: DamageContext) -> void:
	pass

func resolve_death(combat_id: int, reason := "") -> void:
	pass

func apply_status(target_id: int, status_state_or_id, duration := 0, intensity := 0) -> void:
	pass

func remove_status(target_id: int, status_id: String) -> void:
	pass
