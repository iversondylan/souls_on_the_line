extends CardAction

const FOCUSED_STATUS = preload("res://statuses/focused.tres")
const PINPOINT_STATUS = preload("res://statuses/pinpoint.tres")
var duration := 2
#var focused_duration := 2

func activate(targets: Array[Node]) -> bool:
	var action_processed: bool = false
	
	var correct_targets: Array[Fighter] = correct_fighters(targets)
	if !correct_targets:
		return false
	
	player.spend_mana(card_data)
	#attack_group = 1
	
	#var focus_effect := FocusEffect.new()
	#focus_effect.sound = card_data.sound
	#focus_effect.execute(correct_targets)
	
	var status_effect := StatusEffect.new()
	var focused_status := FOCUSED_STATUS.duplicate()
	focused_status.duration = duration
	status_effect.status = focused_status
	status_effect.execute(correct_targets)
	
	status_effect = StatusEffect.new()
	var pinpoint_status := PINPOINT_STATUS.duplicate()
	pinpoint_status.duration = duration
	status_effect.status = pinpoint_status
	status_effect.execute(correct_targets)
	
	action_processed = true
	return action_processed

func get_description(description: String) -> String:
	##Duration should be moddable
	var mod_duration = duration #player.modifier_system.get_modified_value(duration, Modifier.Type.STATUS_DURATION)
	return description % mod_duration
