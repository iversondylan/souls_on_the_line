class_name MarkedStatus extends Status

const ID := "marked"

func _init() -> void:
	id = ID

func get_tooltip() -> String:
	if duration == 1:
		var base_tooltip: String = "Marked: ranged attacks prioritize this target for 1 turn."
		return base_tooltip
	else:
		var base_tooltip: String = "Marked: ranged attacks prioritize this target for %s turns."
		return base_tooltip % duration
