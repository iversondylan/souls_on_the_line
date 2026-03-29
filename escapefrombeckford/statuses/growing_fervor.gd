class_name GrowingFervorStatus extends Status

const ID := &"growing_fervor"

const SHARED_FERVOR_STATUS := preload("uid://c851i8op6ei1")

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
	return "Growing Fervor: grants Shared Fervor, causing allies to deal +%s damage." % intensity
