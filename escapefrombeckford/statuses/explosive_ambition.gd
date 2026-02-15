class_name ExplosiveAmbition extends Status

const ID := &"explosive_ambition"
var member_var := 0

func get_id() -> String:
	return ID

func init_status(_target: Node) -> void:
	print("Initialize the status for target %s" % _target)

func apply_status(_target: Node) -> void:
	print("The status targets: %s" % _target)
	print("Gets status extent of %s" % member_var)
	status_applied.emit(self)

func get_tooltip() -> String:
	var base_tooltip: String = "Explosive Ambition."
	return base_tooltip % intensity
