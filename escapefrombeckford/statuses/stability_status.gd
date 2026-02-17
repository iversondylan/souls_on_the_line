# stability_status.gd
class_name StabilityStatus extends Status

## Remaining stability is represented by `intensity`
## When intensity reaches 0, stability is broken
const ID := &"stability"
@export var max_stability: int = 10

var _last_known_hp: int = -1

func get_id() -> String:
	return ID

func init_status(target: Node) -> void:
	if !(target is Fighter):
		return
	
	# Initialize posture
	intensity = max_stability
	
	var data := (target as Fighter).combatant_data
	_last_known_hp = data.health
	
	if not data.combatant_data_changed.is_connected(_on_combatant_data_changed):
		data.combatant_data_changed.connect(_on_combatant_data_changed)
	
func _on_combatant_data_changed() -> void:
	var fighter := status_parent
	if !fighter or !fighter.is_alive():
		return

	var data := fighter.combatant_data
	var cur_hp := data.health

	if _last_known_hp < 0:
		_last_known_hp = cur_hp
		return

	var damage_taken := _last_known_hp - cur_hp
	_last_known_hp = cur_hp

	if damage_taken <= 0:
		return

	# Reduce posture
	intensity -= damage_taken

	if intensity <= 0:
		_break_posture()

func _break_posture() -> void:
	# Signal posture break via state or event?

	# Remove this status
	var status_system := status_parent.status_system
	if status_system:
		status_system.remove_status_by_id(get_id())

func on_removed() -> void:
	# Defensive cleanup for any explicit removal hooks
	var fighter := status_parent
	if fighter:
		var data := fighter.combatant_data
		if data and data.combatant_data_changed.is_connected(_on_combatant_data_changed):
			data.combatant_data_changed.disconnect(_on_combatant_data_changed)
	else:
		return
	
	#var ai := fighter.get_node_or_null("NPCAIBehavior")
	#if !ai:
		#return

	var state := fighter.state# : Dictionary = ai.get_meta("ai_state")
	if state:
		state.ai_state[NPCAIBehavior.STABILITY_BROKEN] = true

func get_tooltip() -> String:
	return "Stability: %s remaining. Breaking stability will interrupt this unit’s action." % intensity

func affects_intent_legality() -> bool:
	return true
