# autoload.gd (global) class_name: Autoload

extends Node

const RUN_SCENE := preload("res://run/run.tscn")
const PLAYER_CATALOG := preload("uid://b2ewfy12rhm0l")

var pending_run_profile: RunProfile

func begin_new_run(profile: RunProfile) -> void:
	pending_run_profile = profile
	get_tree().change_scene_to_packed(RUN_SCENE)

func begin_continue_run() -> void:
	var profile := RunProfile.new()
	profile.start_mode = RunProfile.StartMode.CONTINUE_RUN
	pending_run_profile = profile
	get_tree().change_scene_to_packed(RUN_SCENE)

func consume_run_profile_or_default() -> RunProfile:
	var profile := pending_run_profile
	pending_run_profile = null
	if profile != null:
		return profile
	if !OS.has_feature("editor"):
		return null
	return _build_editor_default_run_profile()


func _build_editor_default_run_profile() -> RunProfile:
	var player_catalog := PLAYER_CATALOG
	if player_catalog == null:
		return null
	player_catalog.build_index()
	var default_profile := player_catalog.get_default_profile()
	if default_profile == null:
		return null

	var profile := RunProfile.new()
	profile.start_mode = RunProfile.StartMode.NEW_RUN
	profile.player_profile_id = String(default_profile.profile_id)
	profile.selected_starting_soul_uid = ""
	profile.seed = 0
	return profile
