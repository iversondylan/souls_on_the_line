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
	
	var status_effect := StatusEffect.new()
	status_effect.targets = correct_targets
	var focused_status := FOCUSED_STATUS.duplicate()
	focused_status.duration = duration
	status_effect.status = focused_status
	status_effect.execute()
	
	status_effect = StatusEffect.new()
	status_effect.targets = correct_targets
	var pinpoint_status := PINPOINT_STATUS.duplicate()
	pinpoint_status.duration = duration
	status_effect.status = pinpoint_status
	status_effect.execute()
	
	action_processed = true
	return action_processed

func get_description(description: String, _target_fighter: Fighter = null) -> String:
	##Duration should be moddable
	var mod_duration = duration #player.modifier_system.get_modified_value(duration, Modifier.Type.STATUS_DURATION)
	return description % [floori(PinpointStatus.MODIFIER*100), mod_duration]

func get_unmod_description(description: String) -> String:
	return get_description(description)
