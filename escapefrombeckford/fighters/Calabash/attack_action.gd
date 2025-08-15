extends NPCAction

@export var n_damage := 6
@export var n_attacks := 2

var spree: int = 0

func perform_action() -> void:
	if !combatant:
		return
	###updating target to front combatant###
	if combatant.battle_group is BattleGroupEnemy:
		target = GameState.battle_scene.get_front_or_focus(0)
	else:
		target = GameState.battle_scene.get_front_or_focus(1)
	if target:
		var attack_effect := AttackEffect.new()
		attack_effect.targets = [target]
		attack_effect.n_damage = n_damage
		attack_effect.n_attacks = n_attacks
		attack_effect.sound = sound
		attack_effect.execute([combatant])

func is_performable() -> bool:
	if spree <= 1:
		return true
	else:
		return false
#
func update_action_intent() -> void:
	if n_attacks == 1:
		intent_icon.text = str(n_damage)
	else:
		intent_icon.text = str(n_attacks) + "x" + str(n_damage)

func other_action_performed(npc_action: NPCAction) -> void:
	spree = 0
