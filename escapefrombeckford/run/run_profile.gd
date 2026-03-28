# run_profile.gd

class_name RunProfile
extends RefCounted

enum StartMode {
	NEW_RUN,
	CONTINUE_RUN,
}

var start_mode: StartMode = StartMode.NEW_RUN
var player_profile_id: String = ""
var selected_starting_soul_uid: String = ""
var seed: int = 0
