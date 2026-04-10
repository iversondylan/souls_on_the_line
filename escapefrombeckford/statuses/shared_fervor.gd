# shared_fervor.gd

class_name SharedFervorStatus extends Aura

const ID := &"shared_fervor"

func get_id() -> StringName:
	return ID


func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Shared Fervor: allies deal +%s damage." % intensity
