# meta-name: NPCAction
# meta-description: Create an action script for an NPCAction node
class_name MyNewNPCAction extends NPCAction

var spree: int = 0


func perform_action() -> void:
	if !combatant:
		return
		var tween := create_tween().set_trans(Tween.TRANS_QUINT)
		spree += 1
		tween.tween_interval(0.25)
		
		tween.finished.connect(
			func():
				action_performed.emit(self)
				combatant.turn_complete()
		)
	else:
		var tween := create_tween()
		tween.tween_interval(0.5)
		tween.finished.connect(
			func():
				action_performed.emit(self)
				combatant.turn_complete()
		)


func is_performable() -> bool:
	if spree <= 1:
		return true
	else:
		return false
#
func update_action_intent() -> void:
	intent_data.text = ""

func other_action_performed(npc_action: NPCAction) -> void:
	spree = 0
