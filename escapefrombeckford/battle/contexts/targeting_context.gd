# targeting_context.gd
class_name TargetingContext extends RefCounted

enum Stage {
	NONE,
	RETARGET,
	INTERPOSE,
	FINALIZE,
}

var api: SimBattleAPI
var source_id: int = 0
var allow_dead_source: bool = false
var source_group_index: int = -1
var defending_group_index: int = -1

var target_type: int = Attack.Targeting.STANDARD
var attack_mode: int = Attack.Mode.MELEE
var params: Dictionary = {}
var explicit_target_ids: Array[int] = []

var base_target_ids: Array[int] = []
var working_target_ids: Array[int] = []
var final_target_ids: Array[int] = []
var redirect_target_id: int = 0
var is_single_target_intent: bool = false
var current_stage: int = Stage.NONE
