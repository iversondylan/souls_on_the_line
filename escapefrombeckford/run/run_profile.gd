# run_profile.gd

class_name RunProfile
extends RefCounted

enum StartMode {
	NEW_RUN,
	CONTINUE_RUN,
	LOAD_DEBUG_SLOT,
	TUTORIAL,
}

var start_mode: StartMode = StartMode.NEW_RUN
var player_profile_id: String = ""
var selected_starting_soul_uid: String = ""
var seed: int = 0
var debug_slot_name: String = ""
