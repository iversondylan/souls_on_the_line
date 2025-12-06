#class_name MyNewNPCAction 
extends NPCAction

const MIGHT_STATUS = preload("res://statuses/might.tres")

@export var intensity_per_action := 5

var hp_threshold := 40
var usages := 0


func perform_action() -> void:
	if !combatant:
		return
	
	var status_effect := StatusEffect.new()
	status_effect.targets = [combatant]
	var might := MIGHT_STATUS.duplicate() as Might
	might.intensity = intensity_per_action
	status_effect.status = might
	status_effect.execute()
	
	get_tree().create_timer(0.6, false).timeout.connect(
		func():
			action_performed.emit(self)
			combatant.resolve_action()
	)



func is_performable() -> bool:
	var hp_under_threshold := combatant.combatant_data.health <= hp_threshold
	
	if usages == 0 or (usages == 1 and hp_under_threshold):
		usages += 1
		return true
	return false
#
func update_action_intent() -> void:
	intent_data.text = "%s" % intensity_per_action

func other_action_performed(_npc_action: NPCAction) -> void:
	pass
