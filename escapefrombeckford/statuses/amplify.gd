class_name AmplifyStatus extends Status

const MODIFIER := 0.5

func apply_status(_target: Node) -> void:
	print("%s should deal %s%% more damage." % [_target, MODIFIER*100])

#func apply_status(_target: Node) -> void:
	#print("The status targets: %s" % _target)
	#print("Gets status extent of %s" % member_var)
	#status_applied.emit(self)

func _on_status_changed() -> void:
	print("Amplify status: deals increased damage for %s turn(s)" % duration)
