extends NPCAction

@export var n_damage := 6
func perform_action() -> void:
	if !combatant:
		return
	###updating target to front combatant###
	if combatant.battle_group is BattleGroupEnemy:
		target = battle_scene.get_front_or_focus(0)
	else:
		target = battle_scene.get_front_or_focus(1)
	if target:
		var attack_effect := BasicMeleeAttackEffect.new()
		#attack_effect.targets = [target]
		attack_effect.attacker = combatant
		attack_effect.n_damage = combatant.combatant_data.max_mana_red
		attack_effect.sound = sound
		attack_effect.execute([target])

func is_performable() -> bool:
	return true
#
func update_action_intent() -> void:
	n_damage = battle_scene.get_player().combatant_data.max_mana_red
	intent_icon.text = str(n_damage)
