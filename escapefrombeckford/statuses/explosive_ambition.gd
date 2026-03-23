class_name ExplosiveAmbition extends Status

const ID := &"explosive_ambition"
var member_var := 0

func get_id() -> StringName:
	return ID

func init_status(_target: Node) -> void:
	print("Initialize the status for target %s" % _target)

func apply_status(_target: Node) -> void:
	print("The status targets: %s" % _target)
	print("Gets status extent of %s" % member_var)
	status_applied.emit(self)

func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Explosive Ambition."
