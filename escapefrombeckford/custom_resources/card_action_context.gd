class_name CardActionContext extends RefCounted

var player: Player
var battle_scene: BattleScene
var card_data: CardData
var resolved_target: CardResolvedTarget


# Pipeline outputs (mutable)
var summoned_fighters: Array[Fighter] = []
var affected_fighters: Array[Fighter] = []
