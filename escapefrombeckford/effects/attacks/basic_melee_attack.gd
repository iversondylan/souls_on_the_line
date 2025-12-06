class_name BasicMeleeAttackEffect extends AttackEffect

func execute_step() -> void:
	##if no remaining n_attacks, finish the attack.
	if n_attacks <= 0:
		finish_attack()
		return
	
	##get target(s) from modifier pipeline
	targets = battle_scene.get_targets_for_attack_effect(self, attacker)
	
	##if no valid targets, proceed to next hit.
	if targets.is_empty():
		n_attacks -= 1
		_on_hit_finished()
		return
	
	##make tween to go to target(s)
	var tween := battle_scene.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUINT)
	attacker.info_visible(false)
	var end := get_mean_position()
	tween.tween_property(attacker, "global_position", end, 0.4)
	
	##make and queue a damage effect
	var damage_effect := DamageEffect.new()
	damage_effect.targets = targets
	damage_effect.n_damage = attacker.modifier_system.get_modified_value(
		n_damage, Modifier.Type.DMG_DEALT
	)
	damage_effect.sound = sound
	tween.tween_callback(damage_effect.execute)
	
	##small delay, then proceed to next hit
	tween.tween_interval(0.2)
	tween.tween_callback(_on_hit_finished)
	n_attacks -= 1

func _on_hit_finished() -> void:
	if n_attacks > 0:
		execute_step()
	else:
		finish_attack()

func finish_attack() -> void:
	var tween := attacker.create_tween().set_trans(Tween.TRANS_QUINT)
	if explode:
		tween.tween_callback(func(): attacker.die())
	else:
		tween.tween_property(
			attacker,
			"position",
			attacker.anchor_position,
			0.4
		)
		tween.tween_callback(func():
			attacker.resolve_action()
			attacker.info_visible(true)
			)
