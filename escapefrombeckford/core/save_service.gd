extends Node

const APP_STATE_SAVE_PATH := "user://app_state.tres"
const PROFILES_DIR_PATH := "user://profiles"
const PROFILE_DATA_FILENAME := "profile_data.tres"
const ACTIVE_RUN_FILENAME := "active_run.tres"
const DEBUG_RUN_DIRNAME := "debug_runs"

const LEGACY_PROFILE_SAVE_PATH := "user://profile_data.tres"
const LEGACY_ACTIVE_RUN_SAVE_PATH := "user://active_run.tres"
const LEGACY_DEBUG_RUN_DIR_PATH := "user://debug_runs"
const LEGACY_DEFAULT_PROFILE_NAME := "Default Profile"

var _app_state_cache: AppStateData = null
var _profile_cache: ProfileData = null
var _profile_cache_key: String = ""


func _ready() -> void:
	load_or_create_app_state()
	if has_active_user_profile():
		load_or_create_profile()


func load_or_create_app_state() -> AppStateData:
	if _app_state_cache == null:
		var had_saved_app_state := FileAccess.file_exists(APP_STATE_SAVE_PATH)
		_app_state_cache = load_app_state()
		if !had_saved_app_state:
			_migrate_legacy_single_profile_if_needed()
			save_app_state(_app_state_cache)
	return _app_state_cache


func load_app_state() -> AppStateData:
	var loaded := _load_resource(APP_STATE_SAVE_PATH) as AppStateData
	if loaded == null:
		loaded = AppStateData.new()
	_normalize_app_state(loaded)
	return loaded


func save_app_state(app_state: AppStateData) -> bool:
	if app_state == null:
		return false
	_normalize_app_state(app_state)
	_app_state_cache = app_state
	return _save_resource(app_state, APP_STATE_SAVE_PATH)


func list_user_profiles() -> Array[UserProfileInfo]:
	var app_state := load_or_create_app_state()
	var profiles := app_state.profiles.duplicate()
	profiles.sort_custom(_sort_user_profiles)
	return profiles


func get_user_profile_info(profile_key: String) -> UserProfileInfo:
	if profile_key.is_empty():
		return null
	var app_state := load_or_create_app_state()
	for info in app_state.profiles:
		if info != null and String(info.profile_key) == profile_key:
			return info
	return null


func get_active_user_profile_info() -> UserProfileInfo:
	return get_user_profile_info(get_active_user_profile_key())


func has_active_user_profile() -> bool:
	return !get_active_user_profile_key().is_empty()


func get_active_user_profile_key() -> String:
	var app_state := load_or_create_app_state()
	var profile_key := String(app_state.active_user_profile_key)
	if profile_key.is_empty():
		return ""
	return profile_key if get_user_profile_info(profile_key) != null else ""


func set_active_user_profile(profile_key: String) -> bool:
	if get_user_profile_info(profile_key) == null:
		return false
	var app_state := load_or_create_app_state()
	if String(app_state.active_user_profile_key) == profile_key:
		return true
	app_state.active_user_profile_key = profile_key
	_profile_cache = null
	_profile_cache_key = ""
	return save_app_state(app_state)


func clear_active_user_profile() -> void:
	var app_state := load_or_create_app_state()
	if String(app_state.active_user_profile_key).is_empty():
		return
	app_state.active_user_profile_key = ""
	_profile_cache = null
	_profile_cache_key = ""
	save_app_state(app_state)


func user_profile_key_from_name(profile_name: String) -> String:
	return _sanitize_key_from_name(profile_name, "profile")


func debug_slot_key_from_name(slot_name: String) -> String:
	return _sanitize_key_from_name(slot_name, "debug_run")


func create_user_profile(display_name: String) -> UserProfileInfo:
	var trimmed := display_name.strip_edges()
	if trimmed.is_empty():
		return null

	var app_state := load_or_create_app_state()
	var info := _create_user_profile_info(app_state, trimmed)
	if info == null:
		return null

	_ensure_profile_dir_exists(info.profile_key)
	if !save_app_state(app_state):
		app_state.profiles.erase(info)
		return null
	if !save_profile(ProfileData.new(), info.profile_key):
		app_state.profiles.erase(info)
		save_app_state(app_state)
		return null
	return info


func load_or_create_profile(user_profile_key: String = "") -> ProfileData:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return null
	if _profile_cache != null and _profile_cache_key == resolved_key:
		return _profile_cache

	_profile_cache_key = resolved_key
	_profile_cache = load_profile(resolved_key)
	_migrate_legacy_debug_mode_to_profile(_profile_cache, resolved_key)
	if !FileAccess.file_exists(_profile_data_path(resolved_key)):
		save_profile(_profile_cache, resolved_key)
	return _profile_cache


func load_profile(user_profile_key: String = "") -> ProfileData:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return null
	var loaded := _load_resource(_profile_data_path(resolved_key)) as ProfileData
	if loaded == null:
		loaded = ProfileData.new()
	_normalize_profile_data(loaded)
	return loaded


func save_profile(profile: ProfileData, user_profile_key: String = "") -> bool:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if profile == null or resolved_key.is_empty():
		return false
	_normalize_profile_data(profile)
	_ensure_profile_dir_exists(resolved_key)
	_profile_cache = profile
	_profile_cache_key = resolved_key
	return _save_resource(profile, _profile_data_path(resolved_key))


func has_active_run(user_profile_key: String = "") -> bool:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	return !resolved_key.is_empty() and FileAccess.file_exists(_active_run_path(resolved_key))


func clear_active_run(user_profile_key: String = "") -> void:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return
	var path := _active_run_path(resolved_key)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func load_active_run(user_profile_key: String = "") -> RunState:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return null
	var result := _load_run_state_from_path(_active_run_path(resolved_key), true)
	if result == null:
		return null
	if String(result.player_profile_id).is_empty():
		push_warning("SaveService: active run is missing player_profile_id; clearing incompatible save")
		clear_active_run(resolved_key)
		return null
	return result


func save_active_run(run_state: RunState, user_profile_key: String = "") -> bool:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if run_state == null or resolved_key.is_empty():
		return false
	_ensure_profile_dir_exists(resolved_key)
	return _save_resource(run_state, _active_run_path(resolved_key))


func list_debug_run_saves(user_profile_key: String = "") -> Array[DebugRunSaveInfo]:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return []
	var dir_path := _debug_run_dir_path(resolved_key)
	if !DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		return []

	var saves: Array[DebugRunSaveInfo] = []
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		return saves

	dir.list_dir_begin()
	var entry := dir.get_next()
	while !entry.is_empty():
		if !dir.current_is_dir() and entry.get_extension() == "tres":
			var slot_key := entry.get_basename()
			var path := _debug_run_path_from_key(slot_key, resolved_key)
			var info := DebugRunSaveInfo.new()
			info.slot_key = slot_key
			info.file_name = entry
			info.modified_unix_time = int(FileAccess.get_modified_time(ProjectSettings.globalize_path(path)))
			var loaded := _load_run_state_from_path(path, false)
			if loaded != null:
				info.display_name = loaded.resource_name if !loaded.resource_name.is_empty() else slot_key
				info.player_profile_id = String(loaded.player_profile_id)
				info.gold = int(loaded.gold)
			else:
				info.display_name = slot_key
			saves.append(info)
		entry = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(_sort_debug_run_info_newest_first)
	return saves


func save_debug_run(run_state: RunState, slot_name: String, user_profile_key: String = "") -> bool:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if run_state == null or resolved_key.is_empty():
		return false
	_ensure_debug_run_dir_exists(resolved_key)
	var key := debug_slot_key_from_name(slot_name)
	var snapshot := run_state.duplicate(true) as RunState
	if snapshot == null:
		snapshot = run_state
	snapshot.resource_name = slot_name.strip_edges()
	return _save_resource(snapshot, _debug_run_path_from_key(key, resolved_key))


func load_debug_run(slot_name: String, user_profile_key: String = "") -> RunState:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return null
	var key := debug_slot_key_from_name(slot_name)
	return _load_run_state_from_path(_debug_run_path_from_key(key, resolved_key), false)


func delete_debug_run(slot_name: String, user_profile_key: String = "") -> bool:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return false
	var key := debug_slot_key_from_name(slot_name)
	var path := _debug_run_path_from_key(key, resolved_key)
	if !FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _load_resource(path: String) -> Resource:
	if !FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path)


func _save_resource(resource: Resource, path: String) -> bool:
	if resource == null:
		return false
	_ensure_parent_dir_exists(path)
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		push_warning("SaveService: failed to save %s err=%s" % [path, err])
		return false
	return true


func _ensure_parent_dir_exists(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	var parent_dir := global_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent_dir)


func _resolve_user_profile_key(user_profile_key: String) -> String:
	if !user_profile_key.is_empty():
		return user_profile_key
	return get_active_user_profile_key()


func _profile_root_dir_path(user_profile_key: String) -> String:
	return "%s/%s" % [PROFILES_DIR_PATH, user_profile_key]


func _profile_data_path(user_profile_key: String) -> String:
	return "%s/%s" % [_profile_root_dir_path(user_profile_key), PROFILE_DATA_FILENAME]


func _active_run_path(user_profile_key: String) -> String:
	return "%s/%s" % [_profile_root_dir_path(user_profile_key), ACTIVE_RUN_FILENAME]


func _debug_run_dir_path(user_profile_key: String) -> String:
	return "%s/%s" % [_profile_root_dir_path(user_profile_key), DEBUG_RUN_DIRNAME]


func _debug_run_path_from_key(slot_key: String, user_profile_key: String) -> String:
	return "%s/%s.tres" % [_debug_run_dir_path(user_profile_key), slot_key]


func _ensure_profile_dir_exists(user_profile_key: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_profile_root_dir_path(user_profile_key)))


func _ensure_debug_run_dir_exists(user_profile_key: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_debug_run_dir_path(user_profile_key)))


func _normalize_app_state(app_state: AppStateData) -> void:
	if app_state.profiles == null:
		app_state.profiles = []
	var normalized_profiles: Array[UserProfileInfo] = []
	for info in app_state.profiles:
		if info == null:
			continue
		if String(info.profile_key).is_empty():
			info.profile_key = user_profile_key_from_name(String(info.display_name))
		if String(info.display_name).is_empty():
			info.display_name = String(info.profile_key).capitalize()
		normalized_profiles.append(info)
	app_state.profiles = normalized_profiles
	if !String(app_state.active_user_profile_key).is_empty() and _find_user_profile_info(app_state, String(app_state.active_user_profile_key)) == null:
		app_state.active_user_profile_key = ""


func _normalize_profile_data(profile: ProfileData) -> void:
	if profile == null:
		return
	if profile.soul_recess_state == null:
		profile.soul_recess_state = SoulRecessState.new()


func _create_user_profile_info(app_state: AppStateData, display_name: String) -> UserProfileInfo:
	var profile_key := user_profile_key_from_name(display_name)
	if _find_user_profile_info(app_state, profile_key) != null:
		return null
	var info := UserProfileInfo.new()
	info.profile_key = profile_key
	info.display_name = display_name
	info.created_unix_time = int(Time.get_unix_time_from_system())
	app_state.profiles.append(info)
	return info


func _find_user_profile_info(app_state: AppStateData, profile_key: String) -> UserProfileInfo:
	if app_state == null:
		return null
	for info in app_state.profiles:
		if info != null and String(info.profile_key) == profile_key:
			return info
	return null


func _sort_user_profiles(a: UserProfileInfo, b: UserProfileInfo) -> bool:
	return String(a.display_name).to_lower() < String(b.display_name).to_lower()


func _sort_debug_run_info_newest_first(a: DebugRunSaveInfo, b: DebugRunSaveInfo) -> bool:
	if a.modified_unix_time == b.modified_unix_time:
		return a.display_name < b.display_name
	return a.modified_unix_time > b.modified_unix_time


func _sanitize_key_from_name(name: String, empty_default: String) -> String:
	var trimmed := name.strip_edges().to_lower()
	var key := ""
	var prev_underscore := false
	for i in range(trimmed.length()):
		var ch := trimmed.substr(i, 1)
		var code := ch.unicode_at(0)
		var is_alpha := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if is_alpha or is_digit:
			key += ch
			prev_underscore = false
		elif !prev_underscore:
			key += "_"
			prev_underscore = true
	while key.begins_with("_"):
		key = key.substr(1)
	while key.ends_with("_"):
		key = key.substr(0, key.length() - 1)
	if key.is_empty():
		return empty_default
	return key


func _migrate_legacy_single_profile_if_needed() -> void:
	if !_legacy_data_exists():
		return
	var app_state := _app_state_cache if _app_state_cache != null else AppStateData.new()
	var info := _create_user_profile_info(app_state, LEGACY_DEFAULT_PROFILE_NAME)
	if info == null:
		return

	var profile_key := info.profile_key
	var legacy_profile := _load_resource(LEGACY_PROFILE_SAVE_PATH) as ProfileData
	if legacy_profile != null:
		_normalize_profile_data(legacy_profile)
		app_state.debug_mode = bool(legacy_profile.debug_mode)
		save_profile(legacy_profile, profile_key)
	else:
		save_profile(ProfileData.new(), profile_key)

	var legacy_run := _load_run_state_from_path(LEGACY_ACTIVE_RUN_SAVE_PATH, false)
	if legacy_run != null:
		save_active_run(legacy_run, profile_key)

	_migrate_legacy_debug_runs(profile_key)
	app_state.active_user_profile_key = profile_key
	_app_state_cache = app_state
	save_app_state(app_state)
	_remove_legacy_data()


func _migrate_legacy_debug_mode_to_profile(profile: ProfileData, profile_key: String) -> void:
	if profile == null:
		return
	var app_state := load_or_create_app_state()
	if app_state == null or !bool(app_state.debug_mode) or bool(profile.debug_mode):
		return
	if profile_key != get_active_user_profile_key():
		return
	profile.debug_mode = true
	app_state.debug_mode = false
	save_profile(profile, profile_key)
	save_app_state(app_state)


func _legacy_data_exists() -> bool:
	if FileAccess.file_exists(LEGACY_PROFILE_SAVE_PATH):
		return true
	if FileAccess.file_exists(LEGACY_ACTIVE_RUN_SAVE_PATH):
		return true
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LEGACY_DEBUG_RUN_DIR_PATH))


func _migrate_legacy_debug_runs(profile_key: String) -> void:
	if !DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LEGACY_DEBUG_RUN_DIR_PATH)):
		return
	_ensure_debug_run_dir_exists(profile_key)
	var dir := DirAccess.open(ProjectSettings.globalize_path(LEGACY_DEBUG_RUN_DIR_PATH))
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while !entry.is_empty():
		if !dir.current_is_dir() and entry.get_extension() == "tres":
			var legacy_path := "%s/%s" % [LEGACY_DEBUG_RUN_DIR_PATH, entry]
			var loaded := _load_run_state_from_path(legacy_path, false)
			if loaded != null:
				_save_resource(loaded, _debug_run_path_from_key(entry.get_basename(), profile_key))
		entry = dir.get_next()
	dir.list_dir_end()


func _remove_legacy_data() -> void:
	_remove_file_if_exists(LEGACY_PROFILE_SAVE_PATH)
	_remove_file_if_exists(LEGACY_ACTIVE_RUN_SAVE_PATH)
	_remove_directory_if_exists(LEGACY_DEBUG_RUN_DIR_PATH)


func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_directory_if_exists(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	if !DirAccess.dir_exists_absolute(global_path):
		return
	var dir := DirAccess.open(global_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while !entry.is_empty():
		if !dir.current_is_dir():
			DirAccess.remove_absolute("%s/%s" % [global_path, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(global_path)


func _load_run_state_from_path(path: String, resave_if_needed: bool) -> RunState:
	var loaded := _load_resource(path)
	if loaded == null:
		return null
	var needs_resave := false
	if loaded is RunState:
		var loaded_run := loaded as RunState
		needs_resave = String(loaded_run.player_profile_id).is_empty() \
			or int(loaded_run.map_seed) == 0 \
			or loaded_run.player_run_state == null \
			or int(loaded_run.player_run_state.max_health) <= 0 \
			or _pending_room_in_cleared(loaded_run)

	var migrated := _normalize_active_run(loaded)
	if migrated == null:
		return null
	if resave_if_needed and needs_resave:
		_save_resource(migrated, path)
	return migrated


func _normalize_active_run(resource: Resource) -> RunState:
	var run_state: RunState = null
	if resource is RunState:
		run_state = resource as RunState
	else:
		return null

	if run_state.player_run_state == null:
		run_state.player_run_state = PlayerRunState.new()
	if int(run_state.player_run_state.current_health) <= 0 and int(run_state.player_run_state.max_health) > 0:
		run_state.player_run_state.current_health = int(run_state.player_run_state.max_health)
	run_state.player_run_state.clamp_health()
	if run_state.run_deck == null:
		run_state.run_deck = RunDeck.new()
	if run_state.run_deck.card_collection == null:
		run_state.run_deck.card_collection = CardPile.new()
	run_state.run_deck.normalize_cards()
	if run_state.cleared_room_coords == null:
		run_state.cleared_room_coords = []
	if run_state.pending_shop_card_offer_costs == null:
		run_state.pending_shop_card_offer_costs = []
	if run_state.pending_shop_claimed_card_offer_indices == null:
		run_state.pending_shop_claimed_card_offer_indices = []
	if run_state.pending_shop_arcanum_offer_costs == null:
		run_state.pending_shop_arcanum_offer_costs = []
	if run_state.pending_shop_claimed_arcanum_offer_indices == null:
		run_state.pending_shop_claimed_arcanum_offer_indices = []
	if run_state.pending_reward_gold_rewards == null:
		run_state.pending_reward_gold_rewards = []
	if run_state.pending_reward_claimed_gold_indices == null:
		run_state.pending_reward_claimed_gold_indices = []
	if run_state.pending_reward_claimed_arcanum_indices == null:
		run_state.pending_reward_claimed_arcanum_indices = []
	if int(run_state.map_seed) == 0:
		run_state.map_seed = RNGUtil.seed_from_label(int(run_state.run_seed), "map")
	if run_state.run_rng_snapshot == null:
		run_state.run_rng_snapshot = {}
	if run_state.owned_arcanum_ids == null:
		run_state.owned_arcanum_ids = PackedStringArray()
	_remove_pending_room_from_cleared(run_state)
	return run_state


func _pending_room_in_cleared(run_state: RunState) -> bool:
	if run_state == null:
		return false
	if int(run_state.location_kind) == int(RunState.LocationKind.MAP):
		return false
	if run_state.cleared_room_coords == null:
		return false
	return run_state.cleared_room_coords.has(run_state.pending_room_coord)


func _remove_pending_room_from_cleared(run_state: RunState) -> void:
	if !_pending_room_in_cleared(run_state):
		return
	run_state.cleared_room_coords.erase(run_state.pending_room_coord)
