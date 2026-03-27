extends Node

const PROFILE_SAVE_PATH := "user://profile_data.tres"
const ACTIVE_RUN_SAVE_PATH := "user://active_run.tres"

var _profile_cache: ProfileData = null


func _ready() -> void:
	_profile_cache = load_profile()


func has_active_run() -> bool:
	return FileAccess.file_exists(ACTIVE_RUN_SAVE_PATH)


func clear_active_run() -> void:
	if FileAccess.file_exists(ACTIVE_RUN_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ACTIVE_RUN_SAVE_PATH))


func load_or_create_profile() -> ProfileData:
	if _profile_cache == null:
		_profile_cache = load_profile()
		if !FileAccess.file_exists(PROFILE_SAVE_PATH):
			save_profile(_profile_cache)
	return _profile_cache


func load_profile() -> ProfileData:
	var loaded := _load_resource(PROFILE_SAVE_PATH) as ProfileData
	if loaded != null:
		if loaded.soul_recess_state == null:
			loaded.soul_recess_state = SoulRecessState.new()
		return loaded
	return ProfileData.new()


func save_profile(profile: ProfileData) -> bool:
	if profile == null:
		return false
	if profile.soul_recess_state == null:
		profile.soul_recess_state = SoulRecessState.new()
	_profile_cache = profile
	return _save_resource(profile, PROFILE_SAVE_PATH)


func load_active_run() -> RunAccount:
	var loaded := _load_resource(ACTIVE_RUN_SAVE_PATH) as RunAccount
	if loaded == null:
		return null
	if loaded.player_run_state == null:
		loaded.player_run_state = PlayerRunState.new()
	if loaded.run_deck == null:
		loaded.run_deck = RunDeck.new()
	if loaded.run_deck.card_collection == null:
		loaded.run_deck.card_collection = CardPile.new()
	if loaded.owned_arcanum_ids == null:
		loaded.owned_arcanum_ids = PackedStringArray()
	return loaded


func save_active_run(run_account: RunAccount) -> bool:
	if run_account == null:
		return false
	return _save_resource(run_account, ACTIVE_RUN_SAVE_PATH)


func _load_resource(path: String) -> Resource:
	if !FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path)


func _save_resource(resource: Resource, path: String) -> bool:
	if resource == null:
		return false
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		push_warning("SaveService: failed to save %s err=%s" % [path, err])
		return false
	return true
