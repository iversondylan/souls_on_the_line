# marked.gd

class_name MarkedStatus extends Status

# export settings:
# proc_type: Start of Turn
# number_display_type: Duration
# reapply_type: Duration
# expiration_policy: Duration
# duration: 2
# intensity: 0

const ID := &"marked"

func get_id() -> StringName:
	return ID

func get_tooltip() -> String:
	if duration == 1:
		var base_tooltip: String = "Marked: ranged attacks prioritize this target for 1 turn."
		return base_tooltip
	else:
		var base_tooltip: String = "Marked: ranged attacks prioritize this target for %s turns."
		return base_tooltip % duration
