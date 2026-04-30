# card_action_context.gd
class_name CardActionContext extends RefCounted
#
## Always available
#var card_data: CardData
#
## Optional (menu vs run vs battle)
##var player: Player
#var player_data: PlayerData
#var battle_scene: BattleScene
#var resolved_target: CardResolvedTarget
var api: SimBattleAPI
var card_data: CardData
#
## Pipeline outputs (mutable)
#var summoned_fighters: Array[Fighter] = []
#var affected_fighters: Array[Fighter] = []
