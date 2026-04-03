# vennards_vauxite.gd

extends Arcanum

const ID := &"vennards_vauxite.gd"

var block := 3

func on_player_turn_end(_ctx) -> void:
	pass

func get_id() -> StringName:
	return ID
