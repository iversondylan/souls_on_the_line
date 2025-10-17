class_name ExplosiveAmbition extends Status

var member_var := 0

func init_status(_target: Node) -> void:
	print("Initialize the status for target %s" % _target)

func apply_status(_target: Node) -> void:
	print("The status targets: %s" % _target)
	print("Gets status extent of %s" % member_var)
	status_applied.emit(self)
