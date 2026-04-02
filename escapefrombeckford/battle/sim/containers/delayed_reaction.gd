class_name DelayedReaction extends RefCounted

enum Timing {
	AFTER_STRIKE,
}

var timing: int = Timing.AFTER_STRIKE
var source_reason: String = ""
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""


func execute(_runtime: SimRuntime) -> void:
	pass
