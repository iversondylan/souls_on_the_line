# vennards_vauxite.gd

extends Arcanum

const ID := &"vennards_vauxite.gd"

var block := 3

func on_turn_ended(_api: SimBattleAPI) -> void:
	pass

func get_id() -> StringName:
	return ID
