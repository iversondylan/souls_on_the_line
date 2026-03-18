# stability_status.gd
class_name StabilityStatus extends Status

## Remaining stability is represented by `intensity`
## When intensity reaches 0, stability is broken
const ID := &"stability"
@export var max_stability: int = 10

var _last_known_hp: int = -1

func get_id() -> StringName:
	return ID

#func get_tooltip() -> String:
	#return "Stability: %s remaining. Breaking stability will interrupt this unit’s action." % intensity

func affects_intent_legality() -> bool:
	return true
