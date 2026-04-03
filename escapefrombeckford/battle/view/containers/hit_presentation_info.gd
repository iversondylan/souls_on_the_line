# hit_presentation_info
class_name HitPresentationInfo extends RefCounted

var target_id: int = 0

var amount: int = 0
var before_health: int = 0
var after_health: int = 0
var was_lethal: bool = false
var is_self_recoil: bool = false

var status_events: Array[BattleEvent] = []
var died_event: BattleEvent = null
var faded_event: BattleEvent = null
