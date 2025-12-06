class_name FocusEffect
extends Effect

func execute() -> void:
	if targets.size() != 1:
		return
	targets[0].battle_group.focus = targets[0]
	targets[0].add_status("Focus")
	SFXPlayer.play(sound)
