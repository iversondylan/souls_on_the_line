class_name BasicMeleeAttackEffect extends AttackEffect

func execute(input_targets: Array[Fighter]):
	var tween := attacker.create_tween().set_trans(Tween.TRANS_QUINT)
	attacker.info_visible(false)
	#var retargeting: bool = false
	var targets: Array[Fighter] = _get_valid_targets(input_targets)
	#if targets != input_targets:
		#retargeting = true
	#var start := attacker.global_position
	#var tween: Tween = attacker.create_tween().set_trans(Tween.TRANS_QUINT)
	var end: Vector2
	end = get_mean_position(targets)
	tween.tween_property(attacker, "global_position", end, 0.4)
	var damage_effect := DamageEffect.new()
	
	damage_effect.n_damage = attacker.modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	#modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	
	damage_effect.sound = sound
	tween.tween_callback(damage_effect.execute.bind(targets))
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
			execute(targets)
			)

#func attack(targets: Array[Fighter], n_damage: int, n_attacks: int = 1, retarget: AttackEffect.RetargetPriority = AttackEffect.RetargetPriority.FRONT, explode: bool = false):
	#combatant.health_bar.hide()
	#var retargeting: bool = false
	#if targets.size() == 1 and retarget == AttackEffect.RetargetPriority.FRONT:
		#if !targets[0] or !targets[0].combatant_data.is_alive:
			#var target_battle_group_index: int
			#if get_parent() is BattleGroupEnemy:
				#target_battle_group_index = 0
			#else:
				#target_battle_group_index = 1
			#retargeting = true
			#targets = [battle_scene.get_front_combatant(target_battle_group_index)]
	#var start := global_position
	#var tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT)
	#var end: Vector2
	#end = get_mean_position(targets)
	#tween.tween_property(self, "global_position", end, 0.4)
	#var damage_effect := DamageEffect.new()
	#
	#damage_effect.n_damage = modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	##modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	#
	#damage_effect.sound = combatant_data.attack_sound
	#tween.tween_callback(damage_effect.execute.bind(targets))
	#tween.tween_interval(0.5)
	#n_attacks -= 1
	#if n_attacks <= 0:
		#if explode:
			#tween.finished.connect( func(): die() )
		#else:
			#tween.tween_property(self, "position", anchor_position, 0.4)
			#tween.finished.connect( 
				#func(): 
					#if battle_group.acting_fighters[0] == self:
						#turn_complete()
					#combatant.health_bar.show() )
	#else:
		#tween.finished.connect( func(): 
			#attack(targets, n_damage, n_attacks, retarget, explode)
			#)
