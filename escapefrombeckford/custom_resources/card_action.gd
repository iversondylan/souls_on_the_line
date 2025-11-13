class_name CardAction extends Resource

var card_data: CardData
var battle_scene: BattleScene
var player: Player

func activate(targets: Array[Node]) -> bool:
	print("Must override virtual function activate() in CardAction")
	return false

func is_playable() -> bool:
	return player.can_play_card(card_data)

#enum TargetType {
	#SELF,
	#BATTLEFIELD,
	#ALLY_OR_SELF,
	#ALLY,
	#SINGLE_ENEMY,
	#ALL_ENEMIES,
	#EVERYONE
#}

## This function handles checking for and getting Fighters for all 
## card target types that target fighters. BATTLEFIELD target types
# should not use it because they target TargetAreaLeft 
func correct_fighters(targets: Array[Node]) -> Array[Fighter]:
	match card_data.target_type:
		CardData.TargetType.SELF:
			return [player]
		
		CardData.TargetType.BATTLEFIELD:
			var correct_targets: Array[Fighter] = []
			for target in targets:
				if target is CombatantAreaLeft or target is BattleSceneAreaLeft:
					correct_targets.push_back(target)
			return correct_targets
		
		CardData.TargetType.ALLY_OR_SELF:
			if !targets:
				return []
			var correct_targets: Array[Fighter] = []
			if targets[0] is CombatantTargetArea:
				if targets[0].combatant is Player or targets[0].combatant is SummonedAlly:
					correct_targets.push_back(targets[0].combatant)
			return correct_targets
		
		CardData.TargetType.ALLY:
			if !targets:
				return []
			var correct_targets: Array[Fighter]  = []
			if targets[0] is CombatantTargetArea:
				if targets[0].combatant is SummonedAlly:
					correct_targets.push_back(targets[0].combatant)
			return correct_targets
		
		CardData.TargetType.SINGLE_ENEMY:
			if !targets:
				return []
			var correct_targets: Array[Fighter]  = []
			if targets[0] is CombatantTargetArea:
				if targets[0].combatant is Enemy:
					correct_targets.push_back(targets[0].combatant)
			return correct_targets
		
		CardData.TargetType.ALL_ENEMIES:
			return battle_scene.get_combatants_in_group(1)# as Array[Fighter]
		
		CardData.TargetType.EVERYONE:
			battle_scene.get_all_combatants()# as Array[Fighter]
	return []

func get_fighters(targets: Array[Node]) -> Array[Fighter]:
	var attack_targets: Array[Fighter]
	for target in targets:
		if target is CombatantTargetArea:
			if target.combatant is Fighter:
				attack_targets.push_back(target.combatant)
	return attack_targets

func get_description(description: String) -> String:
	return description

func get_unmod_description(description: String) -> String:
	return get_description(description)
