extends HealAction


func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [floori(of_missing * 100)]
