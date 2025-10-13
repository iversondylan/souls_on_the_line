extends CardAction

const FOCUSED_STATUS = preload("res://statuses/focused.tres")
const PINPOINT_STATUS = preload("res://statuses/pinpoint.tres")
var pinpoint_duration := 1
var focused_duration := 2

func activate(targets: Array[Node]) -> bool:
	var focus_target: Array[Fighter] = []
	var action_processed: bool = false
	
	for target in targets:
		if target is CombatantTargetArea:
			if target.combatant is Enemy:
				focus_target.push_back(target.combatant)
	
	if !player.can_play_card(card_data) or !focus_target:
		return action_processed
	
	player.spend_mana(card_data)
	#attack_group = 1
	
	var focus_effect := FocusEffect.new()
	focus_effect.sound = card_data.sound
	focus_effect.execute(focus_target)
	
	var status_effect := StatusEffect.new()
	var focused_status := FOCUSED_STATUS.duplicate()
	focused_status.duration = focused_duration
	status_effect.status = focused_status
	status_effect.execute(focus_target)
	
	status_effect = StatusEffect.new()
	var pinpoint_status := PINPOINT_STATUS.duplicate()
	pinpoint_status.duration = pinpoint_duration
	status_effect.status = pinpoint_status
	status_effect.execute(focus_target)
	
	action_processed = true
	return action_processed
