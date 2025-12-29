class_name FixedStrikesModel extends NPCStrikesModel

@export var strikes: int = 1

func get_strikes(_ctx: NPCAIContext) -> int:
	return strikes
