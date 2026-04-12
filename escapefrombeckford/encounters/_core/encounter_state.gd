class_name EncounterState extends RefCounted

var flags: Dictionary = {}
var current_step_id: StringName = &""
var consumed_trigger_ids: Dictionary = {}
var capabilities: EncounterCapabilitySet = EncounterCapabilitySet.new()
var active_dialogue: EncounterDialogueRequest = null
var awaiting_dialogue_ack: bool = false
var last_observed_event: EncounterObservedEvent = null
