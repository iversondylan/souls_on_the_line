class_name CardAction extends Resource

var card_data: CardData
var battle_scene: BattleScene
var player: Player

func activate(targets: Array[Node]) -> bool:
	print("Must override virtual function activate() in CardAction")
	return false

func is_playable() -> bool:
	return player.can_play_card(card_data)

func get_fighters(targets: Array[Node]) -> Array[Fighter]:
	var attack_targets: Array[Fighter]
	for target in targets:
		if target is CombatantTargetArea:
			if target.combatant is Fighter:
				attack_targets.push_back(target.combatant)
	return attack_targets
