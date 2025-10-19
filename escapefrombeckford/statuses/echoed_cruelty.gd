class_name EchoedCrueltyStatus extends Status

#var member_var := 0

func init_status(_target: Node) -> void:
	status_changed.connect(_on_status_changed)
	_on_status_changed()

func apply_status(_target: Node) -> void:
	print("Status applied: Echoed Cruelty")
	#print("Gets status extent of %s" % member_var)
	#status_applied.emit(self)

func _on_status_changed() -> void:
	print("status changed: Echoed Cruelty")
