# action_step_presentation_info.gd

class_name ActionStepPresentationInfo extends RefCounted

var marker: BattleEvent = null
var events: Array[BattleEvent] = []

var step_kind: int = DirectorAction.ActionKind.GENERIC
var actor_id: int = 0
var target_ids: Array[int] = []

var t0_ratio: float = 0.0
var t1_ratio: float = 1.0
