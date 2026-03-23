class_name CruelDominionStatus extends Status

const ID := &"cruel_dominion"

const ECHOED_CRUELTY_STATUS := preload("res://statuses/echoed_cruelty.tres")

func get_id() -> StringName:
	return ID

#func apply_status(target: Node) -> void:
	#if !(target is Fighter):
		#return
#
	#var echoed := ECHOED_CRUELTY_STATUS.duplicate()
	#echoed.intensity = intensity
#
	#var effect := StatusEffect.new()
	#effect.targets = [target]
	#effect.status = echoed
	#effect.execute((target as Fighter).battle_scene.api)
#
	#status_applied.emit(self)

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Cruel Dominion: each turn, empower your allies to deal %s additional damage." % intensity
