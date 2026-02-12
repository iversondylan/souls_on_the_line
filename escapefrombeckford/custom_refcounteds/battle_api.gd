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
