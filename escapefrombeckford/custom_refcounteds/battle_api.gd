# battle_api.gd
class_name BattleAPI extends RefCounted

# Lookup / targeting support (models + effects)
func is_alive(_combat_id: int) -> bool:
	return false

func get_team(_combat_id: int) -> int:
	return -1

func get_targets_for_attack_sequence(_ctx) -> Array:
	return []

# Core verbs
func resolve_damage(_ctx: DamageContext) -> void:
	push_error("BattleAPI.resolve_damage not implemented")


func modify_damage_amount(_ctx: DamageContext, base: int) -> int:
	return base

func apply_damage_amount(_ctx: DamageContext, _amount: int) -> void:
	pass

func on_damage_applied(_ctx: DamageContext) -> void:
	pass

func resolve_death(_combat_id: int, _reason := "") -> void:
	push_error("BattleAPI.resolve_death not implemented")

func apply_status(ctx: StatusContext) -> void:
	pass

func remove_status(ctx: RemoveStatusContext) -> void:
	pass

func summon(ctx: SummonContext) -> void:
	pass

func resolve_heal(ctx: HealContext) -> void:
	# base class no-op (sim/live override via runner)
	pass

func resolve_move(ctx: MoveContext) -> void:
	pass

func resolve_attack_now(ctx: AttackNowContext) -> void:
	pass

func play_sfx(sound: Sound) -> void:
	if sound:
		SFXPlayer.play(sound)

# spatial / ordering
func get_group(combat_id: int) -> int:
	return -1

func get_rank_in_group(combat_id: int) -> int:
	return -1

func get_combatants_in_group(group_index: int, allow_dead := false) -> Array[int]:
	return [] # ids, front->back

func get_front_combatant_id(group_index: int) -> int:
	return -1

# relations
func get_opposing_group(group_index: int) -> int:
	return -1

func get_enemies_of(combat_id: int) -> Array[int]:
	return []

func get_allies_of(combat_id: int) -> Array[int]:
	return []

# status queries (data-first)
func has_status(combat_id: int, status_id: StringName) -> bool:
	return false

func get_status_stacks(combat_id: int, status_id: StringName) -> int:
	return -1

# “Marked” helper (optional convenience)
func find_marked_ranged_redirect_target(_attacker_id: int) -> int:
	return 0

func get_player_pos_delta(combat_id: int) -> int:
	# live: use battle_scene.get_player_pos_delta(fighter)
	# sim: compute based on rank relative to player id
	return 0
