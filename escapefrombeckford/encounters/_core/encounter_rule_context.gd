class_name EncounterRuleContext extends RefCounted

var director = null
var state = null
var definition = null
var battle = null
var current_step = null
var observed_event = null
var gate_request = null

func get_current_step_id() -> StringName:
	if current_step != null:
		return current_step.id
	if state != null:
		return state.current_step_id
	return &""

func get_flag(flag_name: StringName) -> Variant:
	if state == null:
		return null
	return state.flags.get(flag_name, null)

func get_card_uid() -> StringName:
	if gate_request != null and gate_request.card_uid != &"":
		return gate_request.card_uid
	if observed_event != null and observed_event.card_uid != &"":
		return observed_event.card_uid
	return &""

func get_insert_index() -> int:
	if gate_request != null and gate_request.insert_index >= 0:
		return gate_request.insert_index
	if observed_event != null:
		return observed_event.insert_index
	return -1

func get_event_name() -> StringName:
	return observed_event.name if observed_event != null else &""

func get_battle_event_type() -> int:
	return observed_event.battle_event_type if observed_event != null else -1

func get_request_kind() -> int:
	return gate_request.kind if gate_request != null else -1
