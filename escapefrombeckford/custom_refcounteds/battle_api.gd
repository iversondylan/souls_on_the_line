# battle_api.gd
class_name BattleAPI extends RefCounted

var status_catalog: StatusCatalog

# Lookup / targeting support
func is_alive(_combat_id: int) -> bool:
	return false

func get_team(_combat_id: int) -> int:
	return -1

func get_targets_for_attack_sequence(_ctx) -> Array:
	return []

func get_combatants_in_group(_group_index: int, _allow_dead := false) -> Array[int]:
	return []

func get_n_combatants_in_group(group_index: int, allow_dead := false) -> int:
	return get_combatants_in_group(group_index, allow_dead).size()

func get_rank_in_group(_combat_id: int) -> int:
	return -1

func has_status(_combat_id: int, _status_id: StringName) -> bool:
	return false

func run_status_proc(_target_id: int, _proc_type: Status.ProcType) -> void:
	pass

func find_marked_ranged_redirect_target(_attacker_id: int) -> int:
	return 0


# --------------------------
# Core verbs (queued in live)
# --------------------------

#func resolve_damage(_ctx: DamageContext) -> void:
	#push_error("BattleAPI.resolve_damage not implemented")

func resolve_damage_immediate(ctx: DamageContext) -> int:
	# default: just enqueue like normal
	#resolve_damage(ctx)
	return 0

func resolve_death(_combat_id: int, _reason := "") -> void:
	push_error("BattleAPI.resolve_death not implemented")

func apply_status(_ctx: StatusContext) -> void:
	pass

func remove_status(_ctx: RemoveStatusContext) -> void:
	pass

func summon(_ctx: SummonContext) -> void:
	pass

func resolve_heal(_ctx: HealContext) -> void:
	pass

func resolve_move(_ctx: MoveContext) -> void:
	pass

func resolve_attack_now(_ctx: AttackNowContext) -> void:
	pass


# --------------------------
# DamageResolver hooks
# --------------------------
func modify_damage_amount(_ctx: DamageContext, base: int) -> int:
	return base

func apply_damage_amount(_ctx: DamageContext, _amount: int) -> void:
	pass

func on_damage_applied(_ctx: DamageContext) -> void:
	pass


func play_sfx(sound: Sound) -> void:
	if sound:
		SFXPlayer.play(sound)

func on_card_played(_ctx: CardActionContextSim) -> void:
	pass

# spatial / ordering
func get_group(combat_id: int) -> int:
	return -1

func get_front_combatant_id(group_index: int) -> int:
	return -1

# relations
func get_opposing_group(group_index: int) -> int:
	return -1

func get_enemies_of(combat_id: int) -> Array[int]:
	return []

func get_allies_of(combat_id: int) -> Array[int]:
	return []


func get_status_intensity(combat_id: int, status_id: StringName) -> int:
	return -1

func get_player_pos_delta(combat_id: int) -> int:
	# live: use battle_scene.get_player_pos_delta(fighter)
	# sim: compute based on rank relative to player id
	return 0

# ----------------
# Turn Flow Events
# ----------------

#func run_status_procs(ctx: StatusProcContext) -> void:
	## default: enqueue on runner / sim runs inline
	#pass
