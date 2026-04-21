# shared_fervor.gd

class_name SharedFervorStatus extends Aura

const ID := &"shared_fervor"

func get_id() -> StringName:
	return ID


func get_tooltip(stacks: int = 0) -> String:
	return "Shared Fervor: allies deal +%s damage." % stacks
