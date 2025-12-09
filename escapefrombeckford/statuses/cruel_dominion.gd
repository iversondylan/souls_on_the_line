class_name CruelDominionStatus extends Status

const ECHOED_CRUELTY_STATUS := preload("res://statuses/echoed_cruelty.tres")

func apply_status(target: Node) -> void:
	if !(target is Fighter):
		return

	var echoed := ECHOED_CRUELTY_STATUS.duplicate()
	echoed.intensity = intensity

	var effect := StatusEffect.new()
	effect.targets = [target]
	effect.status = echoed
	effect.execute()

	status_applied.emit(self)

func get_tooltip() -> String:
	return "Cruel Dominion: Each turn, empower your allies to deal %s additional damage." % intensity

#class_name CruelDominionStatus extends Status
#
#const ECHOED_CRUELTY_STATUS := preload("res://statuses/echoed_cruelty.tres")
#
#func apply_status(_target: Node) -> void:
	#var status_effect := StatusEffect.new()
	#status_effect.targets = [_target]
	#var echoed_cruelty := ECHOED_CRUELTY_STATUS.duplicate()
	#echoed_cruelty.intensity = intensity
	#status_effect.status = echoed_cruelty
	#status_effect.execute()
	#status_applied.emit(self)
#
#func get_tooltip() -> String:
	#var base_tooltip: String = "Cruel Dominion: Each turn, empower your allies to deal %s additional damage."
	#return base_tooltip % intensity
