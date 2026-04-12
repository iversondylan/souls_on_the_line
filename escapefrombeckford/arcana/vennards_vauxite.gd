# vennards_vauxite.gd

class_name VennardsVauxiteArcanum extends Arcanum

const ID := &"vennards_vauxite.gd"

var block := 3

func get_timed_proc_flags() -> int:
	return TimedProc.PLAYER_TURN_END

func on_player_turn_end(_ctx: SimArcanumContext) -> void:
	pass

func get_id() -> StringName:
	return ID
