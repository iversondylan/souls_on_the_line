# autoload.gd (global) class_name: Autoload

extends Node

const RUN_SCENE := preload("res://run/run.tscn")
const PLAYER_CATALOG := preload("uid://b2ewfy12rhm0l")

var pending_run_profile: RunProfile

func begin_new_run(profile: RunProfile) -> void:
	_ensure_editor_active_user_profile()
	pending_run_profile = profile
	get_tree().change_scene_to_packed(RUN_SCENE)

func begin_continue_run() -> void:
	_ensure_editor_active_user_profile()
	var profile := RunProfile.new()
	profile.start_mode = RunProfile.StartMode.CONTINUE_RUN
	pending_run_profile = profile
	get_tree().change_scene_to_packed(RUN_SCENE)


func begin_load_debug_run(slot_name: String) -> void:
	_ensure_editor_active_user_profile()
	var profile := RunProfile.new()
	profile.start_mode = RunProfile.StartMode.LOAD_DEBUG_SLOT
	profile.debug_slot_name = slot_name
	pending_run_profile = profile
	get_tree().change_scene_to_packed(RUN_SCENE)


func has_active_user_profile() -> bool:
	return SaveService.has_active_user_profile()


func get_active_user_profile_key() -> String:
	return SaveService.get_active_user_profile_key()


func set_active_user_profile(profile_key: String) -> bool:
	return SaveService.set_active_user_profile(profile_key)


func clear_active_user_profile() -> void:
	SaveService.clear_active_user_profile()


func is_debug_mode_enabled() -> bool:
	var profile := SaveService.load_or_create_profile()
	return profile != null and bool(profile.debug_mode)


func set_debug_mode_enabled(enabled: bool) -> void:
	var profile := SaveService.load_or_create_profile()
	if profile == null:
		return
	if bool(profile.debug_mode) == enabled:
		return
	profile.debug_mode = enabled
	SaveService.save_profile(profile)

func consume_run_profile_or_default() -> RunProfile:
	var profile := pending_run_profile
	pending_run_profile = null
	if profile != null:
		return profile
	if !OS.has_feature("editor"):
		return null
	_ensure_editor_active_user_profile()
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
	profile.seed_int = 0
	return profile


func _ensure_editor_active_user_profile() -> void:
	if !OS.has_feature("editor") or SaveService.has_active_user_profile():
		return
	var profiles := SaveService.list_user_profiles()
	if !profiles.is_empty():
		SaveService.set_active_user_profile(String(profiles[0].profile_key))
		return
	var created := SaveService.create_user_profile("Dev Profile")
	if created != null:
		SaveService.set_active_user_profile(String(created.profile_key))
