# npc_attack_sequence.gd
class_name NPCAttackSequence extends NPCEffectSequence

const TARGET_STANDARD := "target_standard"
const TARGET_OPPONENTS := "target_opponents"
const TARGET_ALL := "target_all"

@export var sound: AudioStream


func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	var fighter := ctx.combatant
	var battle_scene := ctx.battle_scene
	if !fighter or !battle_scene:
		on_done.call()
		return
	
	# Decode semantic parameters with authored fallbacks (matches old "authored defaults" behavior)
	var dmg := int(ctx.params.get(NPCKeys.DAMAGE, 0))
	var strikes := int(ctx.params.get(NPCKeys.STRIKES, 1))
	
	# Defensive: non-positive strikes means "do nothing"
	if strikes <= 0:
		on_done.call()
		return
	
	_execute_strike(ctx, dmg, strikes, on_done)


func _execute_strike(ctx: NPCAIContext, base_dmg: int, remaining: int, on_done: Callable) -> void:
	var fighter := ctx.combatant
	var battle_scene := ctx.battle_scene

	# Finish condition
	if remaining <= 0:
		_finish_attack(ctx, on_done)
		return

	# Safety
	if !fighter or !battle_scene:
		on_done.call()
		return

	# Pull targets dynamically EACH strike (replacement for get_targets_for_attack_effect)
	var targets: Array[Fighter] = battle_scene.get_targets_for_attack_sequence(ctx)

	# No targets -> consume strike and continue (same as old logic)
	if targets.is_empty():
		_execute_strike(ctx, base_dmg, remaining - 1, on_done)
		return

	# Tween to mean target position (same behavior)
	var tween := battle_scene.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUINT)

	fighter.info_visible(false)

	var end_pos := _get_mean_position(targets, fighter)
	tween.tween_property(fighter, "global_position", end_pos, 0.4)

	# Apply damage (with modifier pipeline + sound)
	tween.tween_callback(func():
		var dmg_effect := DamageEffect.new()
		dmg_effect.targets = targets

		# IMPORTANT: match old: modified per hit
		dmg_effect.n_damage = fighter.modifier_system.get_modified_value(
			base_dmg,
			Modifier.Type.DMG_DEALT
		)

		dmg_effect.sound = sound
		dmg_effect.execute()
	)

	# Small delay, then next hit
	tween.tween_interval(0.2)

	tween.tween_callback(func():
		_execute_strike(ctx, base_dmg, remaining - 1, on_done)
	)


func _finish_attack(ctx: NPCAIContext, on_done: Callable) -> void:
	var fighter := ctx.combatant
	if !fighter:
		on_done.call()
		return
	var explode_on_finish := bool(ctx.params.get(NPCKeys.EXPLODE_ON_FINISH, false))
	var tween := fighter.create_tween().set_trans(Tween.TRANS_QUINT)

	if explode_on_finish:
		tween.tween_callback(func(): fighter.die())
	else:
		tween.tween_property(
			fighter,
			"position",
			fighter.anchor_position,
			0.4
		)

	tween.tween_callback(func():
		fighter.info_visible(true)
		on_done.call()
	)


func _get_mean_position(targets: Array[Fighter], fallback: Fighter) -> Vector2:
	if targets.is_empty():
		return fallback.anchor_position

	var sum := Vector2.ZERO
	for t in targets:
		if t:
			sum += t.global_position
	return sum / float(targets.size())
