class_name FocusEffect
extends Effect

func execute(_api: BattleAPI) -> void:
	if targets.size() != 1:
		return
	targets[0].battle_group.focus = targets[0]
	targets[0].add_status("Focus")
	SFXPlayer.play(sound)
