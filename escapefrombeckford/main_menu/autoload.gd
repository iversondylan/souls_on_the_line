# autoload.gd (global) class_name: Autoload

extends Node

const RUN_SCENE := preload("res://run/run.tscn")

var pending_run_profile: RunProfile

func begin_new_run(profile: RunProfile) -> void:
	pending_run_profile = profile
	get_tree().change_scene_to_packed(RUN_SCENE)

func begin_continue_run() -> void:
	var profile := RunProfile.new()
	profile.start_mode = RunProfile.StartMode.CONTINUE_RUN
	pending_run_profile = profile
	get_tree().change_scene_to_packed(RUN_SCENE)

func consume_run_profile() -> RunProfile:
	var profile := pending_run_profile
	pending_run_profile = null
	return profile
