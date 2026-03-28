# run_startup.gd

class_name RunStartup
extends Resource

enum StartupType {NEW_RUN, CONTINUED_RUN}

@export var startup_type: StartupType
@export var player_profile_id: String = ""
@export var run_seed: int = 0  # 0 means "generate one"
@export var selected_starting_soul_uid: String = ""
