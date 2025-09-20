class_name CardAction extends Resource

var card_data: CardData
var battle_scene: BattleScene

func activate(targets: Array[Node], player: Player) -> bool:
	print("Must override virtual function activate() in CardAction")
	return false
