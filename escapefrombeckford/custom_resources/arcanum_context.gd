# arcanum_context.gd
class_name ArcanumContext extends RefCounted

var arcanum_display: ArcanumDisplay

var player: Player
#var player_data: PlayerData
var battle_scene: BattleScene
var params: Dictionary = {}

# Pipeline outputs (mutable)
var summoned_fighters: Array[Fighter] = []
var affected_fighters: Array[Fighter] = []
