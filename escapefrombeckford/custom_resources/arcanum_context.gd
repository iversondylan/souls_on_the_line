# arcanum_context.gd
class_name ArcanumContext extends RefCounted

var arcanum_display: ArcanumDisplay
var api: SimBattleAPI
var player_id: int
#var player_data: PlayerData
#var battle_scene: BattleScene
var params: Dictionary = {}

# Pipeline outputs (mutable)
var summoned_fighters: PackedInt32Array = []
var affected_fighters: PackedInt32Array = []
