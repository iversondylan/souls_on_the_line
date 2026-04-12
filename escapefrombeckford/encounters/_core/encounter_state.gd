class_name EncounterState extends RefCounted

const EncounterCapabilitySetScript = preload("res://encounters/_core/encounter_capability_set.gd")

var flags: Dictionary = {}
var current_step_id: StringName = &""
var consumed_trigger_ids: Dictionary = {}
var capabilities = EncounterCapabilitySetScript.new()
var active_dialogue = null
var awaiting_dialogue_ack: bool = false
var last_observed_event = null
