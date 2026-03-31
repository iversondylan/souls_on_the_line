extends CardAction

class_name GainArmorAction

@export var n_armor: int = 5

func description_arity() -> int:
	return 1


func get_description_values(_ctx: CardActionContext) -> Array:
	return [int(n_armor)]
