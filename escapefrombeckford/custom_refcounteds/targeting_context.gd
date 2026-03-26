# targeting_context.gd
class_name TargetingContext extends RefCounted

var api: SimBattleAPI
var source_id: int = 0

var target_type: int = Attack.Targeting.STANDARD
var attack_mode: int = Attack.Mode.MELEE
var params: Dictionary = {}
var explicit_target_ids: Array[int] = []

var base_target_ids: Array[int] = []
var final_target_ids: Array[int] = []
var redirect_target_id: int = 0
var is_single_target_intent: bool = false
