class_name BasicMeleeAttackEffect extends AttackEffect

#enum RetargetPriority {NONE, FRONT}
#var attacker: Fighter
#var n_damage: int = 5
#var n_attacks: int = 1
#var retarget_priority: RetargetPriority = RetargetPriority.FRONT
#var explode: bool = false

func execute():
	var tween := attacker.create_tween().set_trans(Tween.TRANS_QUINT)
	attacker.info_visible(false)
	targets = battle_scene.get_targets_for_attack_effect(self, attacker)#_get_valid_targets(targets)
	var end: Vector2
	end = get_mean_position(targets)
	tween.tween_property(attacker, "global_position", end, 0.4)
	var damage_effect := DamageEffect.new()
	damage_effect.targets = targets
	damage_effect.n_damage = attacker.modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	tween.tween_callback(damage_effect.execute)
	tween.tween_interval(0.5)
	n_attacks -= 1
	if n_attacks <= 0:
		if explode:
			tween.finished.connect( func(): attacker.die() )
		else:
			tween.tween_property(attacker, "position", attacker.anchor_position, 0.4)
			tween.finished.connect( 
				func(): 
					if attacker.battle_group.acting_fighters[0] == attacker:
						attacker.turn_complete()
					attacker.info_visible(true) )
	else:
		tween.finished.connect( func(): 
			execute()
			)
