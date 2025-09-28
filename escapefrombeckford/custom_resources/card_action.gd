class_name CardAction extends Resource

var card_data: CardData
var battle_scene: BattleScene
var player: Player

func activate(targets: Array[Node]) -> bool:
	print("Must override virtual function activate() in CardAction")
	return false

func is_playable() -> bool:
	return player.can_play_card(card_data)
