class_name FocusedStatus extends Status

const FOCUSED_ID := "focused"

func init_status(_target: Node) -> void:
	#print("%s gets focused for %s turns." % [_target, duration])
	Events.focused_gained.emit(self)

func apply_status(_target: Node) -> void:
	status_applied.emit(self)
	#print("%s gets focused for %s turns." % [_target, duration])

func get_tooltip() -> String:
	if duration == 1:
		var base_tooltip: String = "Isolated: attacks prioritize this target for 1 turn."
		return base_tooltip
	else:
		var base_tooltip: String = "Isolated: attacks prioritize this target for %s turns."
		return base_tooltip % duration
