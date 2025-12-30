# npc_basic_attack_effect.gd
class_name NPCBasicAttackEffect extends NPCAttackEffect


func _execute_step() -> void:
	if n_attacks <= 0:
		_finish_attack()
		return

	var fighter := ctx.combatant
	var battle_scene := ctx.battle_scene

	if !fighter or !battle_scene:
		_finish_attack()
		return

	# Pull targets dynamically each hit
	var targets: Array[Fighter] = battle_scene.get_targets_for_npc_attack_effect(self, fighter)

	# No targets? consume a hit and continue
	if targets.is_empty():
		n_attacks -= 1
		_execute_step()
		return

	# Animate attacker movement
	var tween := battle_scene.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUINT)

	fighter.info_visible(false)

	var end_pos := _get_mean_position(targets, fighter)
	tween.tween_property(fighter, "global_position", end_pos, 0.4)

	# Damage effect
	var damage_effect := DamageEffect.new()
	damage_effect.targets = targets
	damage_effect.n_damage = fighter.modifier_system.get_modified_value(
		n_damage,
		Modifier.Type.DMG_DEALT
	)
	damage_effect.sound = sound

	tween.tween_callback(damage_effect.execute)
	tween.tween_interval(0.2)

	n_attacks -= 1
	tween.tween_callback(_execute_step)


func _get_mean_position(targets: Array[Fighter], fallback: Fighter) -> Vector2:
	if targets.is_empty():
		return fallback.anchor_position

	var sum := Vector2.ZERO
	for t in targets:
		sum += t.global_position
	return sum / float(targets.size())
