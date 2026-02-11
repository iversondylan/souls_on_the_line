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

func play_sfx(sound: Sound) -> void:
	if sound:
		SFXPlayer.play(sound)


## battle_api.gd
#class_name BattleAPI extends RefCounted
#
## --- Lookup / targeting support (models + effects) ---
#func is_alive(combat_id: int) -> bool:
	#return false
#
#func get_team(combat_id: int) -> int:
	#return -1
#
#func get_targets_for_attack_sequence(ctx) -> Array:
	#return []
#
## --- Core resolution verbs ---
#func apply_damage_amount(ctx: DamageContext, amount: int) -> Dictionary:
	#return {}
#
#func resolve_damage(ctx: DamageContext) -> void:
	## TEMP SHIM: keep the game working while refactoring.
	#if !ctx or !ctx.target:
		#return
	## Calls existing Fighter.apply_damage (which does mods + stats + visuals today)
	#ctx.target.apply_damage(ctx)
#
#func resolve_death(combat_id: int, reason := "") -> void:
	#pass
#
#func apply_status(target_id: int, status_state_or_id, duration := 0, intensity := 0) -> void:
	#pass
#
#func remove_status(target_id: int, status_id: String) -> void:
	#pass
#
#func play_sfx(sound: Sound) -> void:
	## TEMP SHIM
	#if sound:
		#SFXPlayer.play(sound)
