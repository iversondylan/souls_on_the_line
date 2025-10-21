class_name CruelDominionStatus extends Status

const ECHOED_CRUELTY_STATUS := preload("res://statuses/echoed_cruelty.tres")
#var intensity_stacks_per_turn := 2

#func init_status(_target: Node) -> void:
	#print("Initialize the status for target %s" % _target)

func apply_status(_target: Node) -> void:
	print("applied cruel dominion status on %s" % _target)
	var status_effect := StatusEffect.new()
	var echoed_cruelty := ECHOED_CRUELTY_STATUS.duplicate()
	echoed_cruelty.intensity = intensity#intensity_stacks_per_turn
	status_effect.status = echoed_cruelty
	status_effect.execute([_target])
	
	#print("Gets status extent of %s" % member_var)
	status_applied.emit(self)
