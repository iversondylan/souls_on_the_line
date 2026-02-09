class_name CruelDominionStatus extends Status

const ID := "cruel_dominion"

const ECHOED_CRUELTY_STATUS := preload("res://statuses/echoed_cruelty.tres")

func _init() -> void:
	id = ID

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
