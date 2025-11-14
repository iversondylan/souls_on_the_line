extends NPCAction

@export var n_damage := 5
@export var n_attacks := 1

var spree: int = 0

#func _ready() -> void:
	#if !sound:
		#sound = load("res://fighters/npc_actions/basic_melee_attack_action.gd")

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
		attack_effect.n_damage = n_damage
		attack_effect.n_attacks = n_attacks
		attack_effect.sound = sound
		attack_effect.execute([target])

func is_performable() -> bool:
	if spree <= 1:
		return true
	else:
		return false
#
func update_action_intent() -> void:
	var modified_dmg := n_damage
	modified_dmg = combatant.modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	#                                                  print("basic_melee_attack_action.gd update_action_intent() Fighter: %s, Text: %s" % [combatant.name, modified_dmg])
	if n_attacks == 1:
		intent_data.base_text = str(modified_dmg)
		intent_data.current_tooltip_text = intent_data.tooltip_text % str(modified_dmg)
	else:
		intent_data.base_text = str(n_attacks) + "x" + str(modified_dmg)
		intent_data.current_tooltip_text = intent_data.tooltip_text % str(n_attacks) + "x" + str(modified_dmg)

func other_action_performed(npc_action: NPCAction) -> void:
	spree = 0

func get_tooltip() -> String:
	var modified_dmg := n_damage
	modified_dmg = combatant.modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	return intent_data.tooltip_text % str(modified_dmg)
#func update_intent_text() -> void:
	
