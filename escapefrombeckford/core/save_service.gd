extends Node

const APP_STATE_SAVE_PATH := "user://app.json"
const PROFILES_DIR_PATH := "user://profiles"
const PROFILE_DATA_FILENAME := "profile.json"
const ACTIVE_RUN_FILENAME := "active_run.json"
const DEBUG_RUN_DIRNAME := "debug_runs"

const FILE_TYPE_APP := "app"
const FILE_TYPE_PROFILE := "profile"
const FILE_TYPE_RUN := "run"
const SAVE_VERSION := 3
const DEFAULT_SOUL_RECESS_SLOT_COUNT := 2
const DEFAULT_ATTUNED_SOUL_PATH := "res://cards/souls/SpectralCloneCard/spectral_clone.tres"

const SERIALIZED_KIND_STRING_NAME := "string_name"
const SERIALIZED_KIND_COLOR := "color"
const SERIALIZED_KIND_VECTOR2 := "vector2"
const SERIALIZED_KIND_VECTOR2I := "vector2i"
const SERIALIZED_KIND_VECTOR3 := "vector3"
const SERIALIZED_KIND_PACKED_STRING_ARRAY := "packed_string_array"
const SERIALIZED_KIND_PACKED_INT32_ARRAY := "packed_int32_array"
const SERIALIZED_KIND_EXTERNAL_RESOURCE := "external_resource"
const SERIALIZED_KIND_SCRIPTED_RESOURCE := "scripted_resource"

var _app_state_cache: AppStateData = null
var _profile_cache: ProfileData = null
var _profile_cache_key: String = ""
var _script_uid_path_cache: Dictionary = {}
var _script_uid_cache_ready: bool = false


func _ready() -> void:
	load_or_create_app_state()
	if has_active_user_profile():
		load_or_create_profile()


func load_or_create_app_state() -> AppStateData:
	if _app_state_cache == null:
		_app_state_cache = load_app_state()
		if !FileAccess.file_exists(APP_STATE_SAVE_PATH):
			save_app_state(_app_state_cache)
	return _app_state_cache


func load_app_state() -> AppStateData:
	var envelope := _read_json_file(APP_STATE_SAVE_PATH)
	var loaded := _decode_app_state(envelope)
	if loaded == null:
		loaded = AppStateData.new()
	_normalize_app_state(loaded)
	return loaded


func save_app_state(app_state: AppStateData) -> bool:
	if app_state == null:
		return false
	_normalize_app_state(app_state)
	_app_state_cache = app_state
	return _write_json_file(APP_STATE_SAVE_PATH, _encode_app_state(app_state))


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
		if info != null and str(info.profile_key) == profile_key:
			return info
	return null


func get_active_user_profile_info() -> UserProfileInfo:
	return get_user_profile_info(get_active_user_profile_key())


func has_active_user_profile() -> bool:
	return !get_active_user_profile_key().is_empty()


func get_active_user_profile_key() -> String:
	var app_state := load_or_create_app_state()
	var profile_key := str(app_state.active_user_profile_key)
	if profile_key.is_empty():
		return ""
	return profile_key if get_user_profile_info(profile_key) != null else ""


func set_active_user_profile(profile_key: String) -> bool:
	if get_user_profile_info(profile_key) == null:
		return false
	var app_state := load_or_create_app_state()
	if str(app_state.active_user_profile_key) == profile_key:
		return true
	app_state.active_user_profile_key = profile_key
	_profile_cache = null
	_profile_cache_key = ""
	return save_app_state(app_state)


func clear_active_user_profile() -> void:
	var app_state := load_or_create_app_state()
	if str(app_state.active_user_profile_key).is_empty():
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


func delete_user_profile(user_profile_key: String) -> bool:
	if user_profile_key.is_empty():
		return false
	var app_state := load_or_create_app_state()
	if _find_user_profile_info(app_state, user_profile_key) == null:
		return false

	var root_path := ProjectSettings.globalize_path(_profile_root_dir_path(user_profile_key))
	if DirAccess.dir_exists_absolute(root_path):
		if !_delete_dir_recursive(root_path):
			push_warning("SaveService: failed to delete profile directory for '%s'" % user_profile_key)
			return false

	for i in range(app_state.profiles.size() - 1, -1, -1):
		var info := app_state.profiles[i]
		if info != null and str(info.profile_key) == user_profile_key:
			app_state.profiles.remove_at(i)

	if str(app_state.active_user_profile_key) == user_profile_key:
		app_state.active_user_profile_key = ""
	if _profile_cache_key == user_profile_key:
		_profile_cache = null
		_profile_cache_key = ""

	return save_app_state(app_state)


func load_or_create_profile(user_profile_key: String = "") -> ProfileData:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return null
	if _profile_cache != null and _profile_cache_key == resolved_key:
		return _profile_cache

	_profile_cache_key = resolved_key
	_profile_cache = load_profile(resolved_key)
	if !FileAccess.file_exists(_profile_data_path(resolved_key)):
		save_profile(_profile_cache, resolved_key)
	return _profile_cache


func load_profile(user_profile_key: String = "") -> ProfileData:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return null
	var envelope := _read_json_file(_profile_data_path(resolved_key))
	var loaded := _decode_profile(envelope)
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
	return _write_json_file(_profile_data_path(resolved_key), _encode_profile(profile))


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
	return _load_run_state_from_path(_active_run_path(resolved_key))


func save_active_run(run_state: RunState, user_profile_key: String = "") -> bool:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if run_state == null or resolved_key.is_empty():
		return false
	_ensure_profile_dir_exists(resolved_key)
	return _write_json_file(_active_run_path(resolved_key), _encode_run_state(run_state))


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
		if !dir.current_is_dir() and entry.get_extension() == "json":
			var slot_key := entry.get_basename()
			var path := _debug_run_path_from_key(slot_key, resolved_key)
			var info := _build_debug_run_info_from_path(slot_key, entry, path)
			if info != null:
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
	return _write_json_file(_debug_run_path_from_key(key, resolved_key), _encode_run_state(run_state, slot_name.strip_edges()))


func load_debug_run(slot_name: String, user_profile_key: String = "") -> RunState:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return null
	var key := debug_slot_key_from_name(slot_name)
	return _load_run_state_from_path(_debug_run_path_from_key(key, resolved_key))


func delete_debug_run(slot_name: String, user_profile_key: String = "") -> bool:
	var resolved_key := _resolve_user_profile_key(user_profile_key)
	if resolved_key.is_empty():
		return false
	var key := debug_slot_key_from_name(slot_name)
	var path := _debug_run_path_from_key(key, resolved_key)
	if !FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _read_json_file(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveService: failed to open %s for read" % path)
		return {}
	var text := file.get_as_text()
	if text.strip_edges().is_empty():
		push_warning("SaveService: empty save file %s" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveService: invalid JSON envelope in %s" % path)
		return {}
	return parsed


func _write_json_file(path: String, dto: Dictionary) -> bool:
	if dto.is_empty():
		return false
	_ensure_parent_dir_exists(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: failed to open %s for write" % path)
		return false
	file.store_string(JSON.stringify(dto, "\t"))
	return true


func _ensure_parent_dir_exists(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	var parent_dir := global_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent_dir)


func _delete_dir_recursive(global_dir_path: String) -> bool:
	if !DirAccess.dir_exists_absolute(global_dir_path):
		return true
	var dir := DirAccess.open(global_dir_path)
	if dir == null:
		return false

	dir.list_dir_begin()
	var entry := dir.get_next()
	while !entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path := global_dir_path.path_join(entry)
		if dir.current_is_dir():
			if !_delete_dir_recursive(child_path):
				dir.list_dir_end()
				return false
		else:
			if DirAccess.remove_absolute(child_path) != OK:
				dir.list_dir_end()
				return false
		entry = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(global_dir_path) == OK


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
	return "%s/%s.json" % [_debug_run_dir_path(user_profile_key), slot_key]


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
		if str(info.profile_key).is_empty():
			info.profile_key = user_profile_key_from_name(str(info.display_name))
		if str(info.display_name).is_empty():
			info.display_name = str(info.profile_key).capitalize()
		normalized_profiles.append(info)
	app_state.profiles = normalized_profiles
	if !str(app_state.active_user_profile_key).is_empty() and _find_user_profile_info(app_state, str(app_state.active_user_profile_key)) == null:
		app_state.active_user_profile_key = ""


func _normalize_profile_data(profile: ProfileData) -> void:
	if profile == null:
		return
	if profile.soul_recess_state == null:
		profile.soul_recess_state = SoulRecessState.new()
	_normalize_soul_recess_state(profile.soul_recess_state)


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
		if info != null and str(info.profile_key) == profile_key:
			return info
	return null


func _sort_user_profiles(a: UserProfileInfo, b: UserProfileInfo) -> bool:
	return str(a.display_name).to_lower() < str(b.display_name).to_lower()


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


func _load_run_state_from_path(path: String) -> RunState:
	var envelope := _read_json_file(path)
	var run_state := _decode_run_state(envelope)
	if run_state == null:
		return null
	if str(run_state.player_profile_id).is_empty():
		push_warning("SaveService: run at %s is missing player_profile_id" % path)
		return null
	return run_state


func _decode_app_state(envelope: Dictionary) -> AppStateData:
	var data := _extract_envelope_data(envelope, FILE_TYPE_APP)
	if data.is_empty():
		return null

	var app_state := AppStateData.new()
	app_state.active_user_profile_key = str(data.get("active_user_profile_key", ""))
	var profile_dicts = data.get("profiles", [])
	if typeof(profile_dicts) == TYPE_ARRAY:
		for value in profile_dicts:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var info := _decode_user_profile_info(value)
			if info != null:
				app_state.profiles.append(info)
	_normalize_app_state(app_state)
	return app_state


func _encode_app_state(app_state: AppStateData) -> Dictionary:
	var profiles: Array[Dictionary] = []
	for info in app_state.profiles:
		if info == null:
			continue
		profiles.append(_encode_user_profile_info(info))
	return {
		"file_type": FILE_TYPE_APP,
		"version": SAVE_VERSION,
		"data": {
			"active_user_profile_key": str(app_state.active_user_profile_key),
			"profiles": profiles,
		},
	}


func _decode_profile(envelope: Dictionary) -> ProfileData:
	var data := _extract_envelope_data(envelope, FILE_TYPE_PROFILE)
	if data.is_empty():
		return null

	var profile := ProfileData.new()
	profile.xp = int(data.get("xp", 0))
	profile.debug_mode = bool(data.get("debug_mode", false))
	profile.unlocked_content_ids = _decode_packed_string_array(data.get("unlocked_content_ids", []))
	profile.soul_recess_state = _decode_soul_recess_state(data.get("soul_recess_state", {}))
	_normalize_profile_data(profile)
	return profile


func _encode_profile(profile: ProfileData) -> Dictionary:
	return {
		"file_type": FILE_TYPE_PROFILE,
		"version": SAVE_VERSION,
		"data": {
			"xp": int(profile.xp),
			"debug_mode": bool(profile.debug_mode),
			"unlocked_content_ids": _encode_packed_string_array(profile.unlocked_content_ids),
			"soul_recess_state": _encode_soul_recess_state(profile.soul_recess_state),
		},
	}


func _decode_run_state(envelope: Dictionary) -> RunState:
	var data := _extract_envelope_data(envelope, FILE_TYPE_RUN)
	if data.is_empty():
		return null

	var run_state := RunState.new()
	run_state.resource_name = str(data.get("save_name", ""))
	run_state.gold = int(data.get("gold", RunState.BASE_STARTING_GOLD))
	run_state.card_reward_choices = int(data.get("card_reward_choices", RunState.BASE_CARD_REWARD_CHOICES))
	run_state.common_weight = float(data.get("common_weight", RunState.BASE_COMMON_WEIGHT))
	run_state.uncommon_weight = float(data.get("uncommon_weight", RunState.BASE_UNCOMMON_WEIGHT))
	run_state.rare_weight = float(data.get("rare_weight", RunState.BASE_RARE_WEIGHT))
	run_state.run_seed = int(data.get("run_seed", 0))
	run_state.map_seed = int(data.get("map_seed", 0))
	run_state.run_rng_snapshot = _decode_run_rng_snapshot(data.get("run_rng_snapshot", {}))
	run_state.player_profile_id = str(data.get("player_profile_id", ""))
	run_state.player_run_state = _decode_player_run_state(data.get("player_run_state", {}))
	run_state.cleared_room_coords = _decode_vector2i_array(data.get("cleared_room_coords", []))
	run_state.location_kind = int(data.get("location_kind", RunState.LocationKind.MAP))
	run_state.pending_room_coord = _decode_vector2i(data.get("pending_room_coord", []), Vector2i(-1, -1))
	run_state.pending_battle_seed = int(data.get("pending_battle_seed", 0))
	run_state.pending_room_seed = int(data.get("pending_room_seed", 0))
	run_state.pending_reward_seed = int(data.get("pending_reward_seed", 0))
	run_state.pending_treasure_arcanum_id = str(data.get("pending_treasure_arcanum_id", ""))
	run_state.pending_shop_card_offer_paths = _decode_packed_string_array(data.get("pending_shop_card_offer_paths", []))
	run_state.pending_shop_card_offer_costs = _decode_int_array(data.get("pending_shop_card_offer_costs", []))
	run_state.pending_shop_claimed_card_offer_indices = _decode_int_array(data.get("pending_shop_claimed_card_offer_indices", []))
	run_state.pending_shop_arcanum_offer_ids = _decode_packed_string_array(data.get("pending_shop_arcanum_offer_ids", []))
	run_state.pending_shop_arcanum_offer_costs = _decode_int_array(data.get("pending_shop_arcanum_offer_costs", []))
	run_state.pending_shop_claimed_arcanum_offer_indices = _decode_int_array(data.get("pending_shop_claimed_arcanum_offer_indices", []))
	run_state.pending_reward_gold_rewards = _decode_int_array(data.get("pending_reward_gold_rewards", []))
	run_state.pending_reward_card_choice_paths = _decode_packed_string_array(data.get("pending_reward_card_choice_paths", []))
	run_state.pending_reward_arcanum_ids = _decode_packed_string_array(data.get("pending_reward_arcanum_ids", []))
	run_state.pending_reward_claimed_gold_indices = _decode_int_array(data.get("pending_reward_claimed_gold_indices", []))
	run_state.pending_reward_card_claimed = bool(data.get("pending_reward_card_claimed", false))
	run_state.pending_reward_claimed_arcanum_indices = _decode_int_array(data.get("pending_reward_claimed_arcanum_indices", []))
	run_state.battle_assignments_by_room_key = _decode_string_dictionary(data.get("battle_assignments_by_room_key", {}))
	run_state.consumed_battle_paths = _decode_packed_string_array(data.get("consumed_battle_paths", []))
	run_state.owned_arcanum_ids = _decode_packed_string_array(data.get("owned_arcanum_ids", []))
	run_state.draftable_cards = _decode_card_pile_from_refs(data.get("draftable_card_refs", []))
	run_state.run_deck = _decode_run_deck(data.get("run_deck", {}))
	_normalize_active_run(run_state)
	return run_state


func _encode_run_state(run_state: RunState, save_name: String = "") -> Dictionary:
	return {
		"file_type": FILE_TYPE_RUN,
		"version": SAVE_VERSION,
		"data": {
			"save_name": save_name,
			"gold": int(run_state.gold),
			"card_reward_choices": int(run_state.card_reward_choices),
			"common_weight": float(run_state.common_weight),
			"uncommon_weight": float(run_state.uncommon_weight),
			"rare_weight": float(run_state.rare_weight),
			"run_seed": int(run_state.run_seed),
			"map_seed": int(run_state.map_seed),
			"run_rng_snapshot": _encode_run_rng_snapshot(run_state.run_rng_snapshot),
			"player_profile_id": str(run_state.player_profile_id),
			"player_run_state": _encode_player_run_state(run_state.player_run_state),
			"cleared_room_coords": _encode_vector2i_array(run_state.cleared_room_coords),
			"location_kind": int(run_state.location_kind),
			"pending_room_coord": _encode_vector2i(run_state.pending_room_coord),
			"pending_battle_seed": int(run_state.pending_battle_seed),
			"pending_room_seed": int(run_state.pending_room_seed),
			"pending_reward_seed": int(run_state.pending_reward_seed),
			"pending_treasure_arcanum_id": str(run_state.pending_treasure_arcanum_id),
			"pending_shop_card_offer_paths": _encode_packed_string_array(run_state.pending_shop_card_offer_paths),
			"pending_shop_card_offer_costs": _encode_int_array(run_state.pending_shop_card_offer_costs),
			"pending_shop_claimed_card_offer_indices": _encode_int_array(run_state.pending_shop_claimed_card_offer_indices),
			"pending_shop_arcanum_offer_ids": _encode_packed_string_array(run_state.pending_shop_arcanum_offer_ids),
			"pending_shop_arcanum_offer_costs": _encode_int_array(run_state.pending_shop_arcanum_offer_costs),
			"pending_shop_claimed_arcanum_offer_indices": _encode_int_array(run_state.pending_shop_claimed_arcanum_offer_indices),
			"pending_reward_gold_rewards": _encode_int_array(run_state.pending_reward_gold_rewards),
			"pending_reward_card_choice_paths": _encode_packed_string_array(run_state.pending_reward_card_choice_paths),
			"pending_reward_arcanum_ids": _encode_packed_string_array(run_state.pending_reward_arcanum_ids),
			"pending_reward_claimed_gold_indices": _encode_int_array(run_state.pending_reward_claimed_gold_indices),
			"pending_reward_card_claimed": bool(run_state.pending_reward_card_claimed),
			"pending_reward_claimed_arcanum_indices": _encode_int_array(run_state.pending_reward_claimed_arcanum_indices),
			"battle_assignments_by_room_key": _encode_string_dictionary(run_state.battle_assignments_by_room_key),
			"consumed_battle_paths": _encode_packed_string_array(run_state.consumed_battle_paths),
			"owned_arcanum_ids": _encode_packed_string_array(run_state.owned_arcanum_ids),
			"draftable_card_refs": _encode_card_pile_refs(run_state.draftable_cards),
			"run_deck": _encode_run_deck(run_state.run_deck),
		},
	}


func _extract_envelope_data(envelope: Dictionary, expected_type: String) -> Dictionary:
	if envelope.is_empty():
		return {}
	if str(envelope.get("file_type", "")) != expected_type:
		push_warning("SaveService: expected %s save, got %s" % [expected_type, str(envelope.get("file_type", "<missing>"))])
		return {}
	if int(envelope.get("version", -1)) != SAVE_VERSION:
		push_warning("SaveService: unsupported %s save version %s" % [expected_type, str(envelope.get("version", "<missing>"))])
		return {}
	var data = envelope.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("SaveService: %s save is missing object data" % expected_type)
		return {}
	return data


func _decode_user_profile_info(data: Dictionary) -> UserProfileInfo:
	var info := UserProfileInfo.new()
	info.profile_key = str(data.get("profile_key", ""))
	info.display_name = str(data.get("display_name", ""))
	info.created_unix_time = int(data.get("created_unix_time", 0))
	if info.profile_key.is_empty():
		return null
	return info


func _encode_user_profile_info(info: UserProfileInfo) -> Dictionary:
	return {
		"profile_key": str(info.profile_key),
		"display_name": str(info.display_name),
		"created_unix_time": int(info.created_unix_time),
	}


func _decode_run_rng_snapshot(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var snapshot_data := value as Dictionary
	var decoded_streams := {}
	var raw_streams := _as_dictionary(snapshot_data.get("streams", {}))
	for key in raw_streams.keys():
		var label := str(key)
		var raw_stream := _as_dictionary(raw_streams[key])
		if raw_stream.is_empty():
			continue
		decoded_streams[label] = {
			"seed": int(raw_stream.get("seed", 0)),
			"rolls": int(raw_stream.get("rolls", 0)),
		}
	return {
		"run_seed": int(snapshot_data.get("run_seed", 0)),
		"streams": decoded_streams,
	}


func _encode_run_rng_snapshot(snapshot: Variant) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {}
	var snapshot_data := snapshot as Dictionary
	var encoded_streams := {}
	var raw_streams := _as_dictionary(snapshot_data.get("streams", {}))
	for key in raw_streams.keys():
		var label := str(key)
		var raw_stream := _as_dictionary(raw_streams[key])
		if raw_stream.is_empty():
			continue
		encoded_streams[label] = {
			"seed": int(raw_stream.get("seed", 0)),
			"rolls": int(raw_stream.get("rolls", 0)),
		}
	return {
		"run_seed": int(snapshot_data.get("run_seed", 0)),
		"streams": encoded_streams,
	}


func _decode_player_run_state(data: Variant) -> PlayerRunState:
	var result := PlayerRunState.new()
	if typeof(data) != TYPE_DICTIONARY:
		return result
	result.current_health = int(data.get("current_health", 0))
	result.max_health = int(data.get("max_health", 0))
	result.clamp_health()
	return result


func _encode_player_run_state(state: PlayerRunState) -> Dictionary:
	return {
		"current_health": int(state.current_health) if state != null else 0,
		"max_health": int(state.max_health) if state != null else 0,
	}


func _decode_soul_recess_state(data: Variant) -> SoulRecessState:
	var state := SoulRecessState.new()
	if typeof(data) != TYPE_DICTIONARY:
		return state
	state.unlocked_slot_count = int(data.get("unlocked_slot_count", DEFAULT_SOUL_RECESS_SLOT_COUNT))
	state.selected_starting_soul_uid = str(data.get("selected_starting_soul_uid", ""))
	state.attuned_souls = _decode_card_snapshot_array(data.get("attuned_souls", []))
	if state.attuned_souls.is_empty():
		state.attuned_souls = _decode_card_snapshot_array(data.get("slot_souls", []))
	_normalize_soul_recess_state(state)
	return state


func _encode_soul_recess_state(state: SoulRecessState) -> Dictionary:
	if state == null:
		return {
			"unlocked_slot_count": DEFAULT_SOUL_RECESS_SLOT_COUNT,
			"selected_starting_soul_uid": "",
			"attuned_souls": [],
		}
	return {
		"unlocked_slot_count": int(state.unlocked_slot_count),
		"selected_starting_soul_uid": str(state.selected_starting_soul_uid),
		"attuned_souls": _encode_card_snapshot_array(state.attuned_souls),
	}


func _normalize_soul_recess_state(state: SoulRecessState) -> void:
	if state == null:
		return
	state.unlocked_slot_count = maxi(int(state.unlocked_slot_count), 0)

	var normalized: Array[CardSnapshot] = []
	for snapshot in state.attuned_souls:
		if normalized.size() >= int(state.unlocked_slot_count):
			break
		var normalized_snapshot := _normalize_attuned_soul_snapshot(snapshot)
		if normalized_snapshot != null:
			normalized.append(normalized_snapshot)

	while normalized.size() < int(state.unlocked_slot_count):
		var default_snapshot := _make_default_attuned_soul_snapshot()
		if default_snapshot == null:
			break
		normalized.append(default_snapshot)

	state.attuned_souls = normalized

	if state.attuned_souls.is_empty():
		state.selected_starting_soul_uid = ""
		return
	if str(state.selected_starting_soul_uid).is_empty():
		return
	if state.get_attuned_soul_snapshot(String(state.selected_starting_soul_uid)) == null:
		state.selected_starting_soul_uid = ""


func _normalize_attuned_soul_snapshot(snapshot: CardSnapshot) -> CardSnapshot:
	if snapshot == null:
		return null
	var restored := snapshot.instantiate_card()
	if restored == null:
		return null
	if int(restored.card_type) != int(CardData.CardType.SOULBOUND):
		return null
	return CardSnapshot.from_card(restored)


func _make_default_attuned_soul_snapshot() -> CardSnapshot:
	var default_card := load(DEFAULT_ATTUNED_SOUL_PATH) as CardData
	if default_card == null:
		return null
	return CardSnapshot.from_card(default_card)


func _decode_run_deck(data: Variant) -> RunDeck:
	var deck := RunDeck.new()
	if typeof(data) != TYPE_DICTIONARY:
		return deck
	deck.soulbound_slot_count = int(data.get("soulbound_slot_count", deck.soulbound_slot_count))
	deck.card_collection = _build_card_pile_from_cards(_decode_card_array(data.get("cards", [])))
	deck.soulbound_slots = _decode_card_array(data.get("soulbound_slots", []))
	return deck


func _encode_run_deck(run_deck: RunDeck) -> Dictionary:
	if run_deck == null:
		return {
			"cards": [],
			"soulbound_slot_count": RunDeck.DEFAULT_SOULBOUND_SLOT_COUNT,
			"soulbound_slots": [],
		}
	return {
		"cards": _encode_card_array(run_deck.card_collection.cards if run_deck.card_collection != null else []),
		"soulbound_slot_count": int(run_deck.get_soulbound_slot_count()),
		"soulbound_slots": _encode_card_array(run_deck.get_soulbound_slot_cards()),
	}


func _build_card_pile_from_cards(cards: Array[CardData]) -> CardPile:
	var pile := CardPile.new()
	for card in cards:
		if card == null:
			continue
		pile.add_back(card)
	return pile


func _decode_card_pile_from_refs(values: Variant) -> CardPile:
	var pile := CardPile.new()
	if typeof(values) != TYPE_ARRAY:
		return pile
	for value in values:
		var ref := str(value)
		if ref.is_empty():
			continue
		var card := load(ref) as CardData
		if card == null:
			push_warning("SaveService: failed to load draftable card ref %s" % ref)
			continue
		pile.add_back(card)
	return pile


func _encode_card_pile_refs(pile: CardPile) -> Array[String]:
	var refs: Array[String] = []
	if pile == null:
		return refs
	for card_data in pile.cards:
		if card_data == null:
			continue
		var ref := _card_resource_uid_ref(card_data)
		if ref.is_empty():
			push_warning("SaveService: draftable card is missing a resource uid/path; skipping %s" % str(card_data.name))
			continue
		refs.append(ref)
	return refs


func _card_resource_uid_ref(card_data: CardData) -> String:
	if card_data == null:
		return ""
	var path := str(card_data.resource_path)
	if path.is_empty():
		return ""
	if path.begins_with("uid://"):
		return path
	var uid := ResourceLoader.get_resource_uid(path)
	if uid > 0:
		return ResourceUID.id_to_text(uid)
	return ""


func _decode_card_array(values: Variant) -> Array[CardData]:
	var cards: Array[CardData] = []
	if typeof(values) != TYPE_ARRAY:
		return cards
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var card := CardSnapshot.deserialize_card_data(value)
		if card != null:
			cards.append(card)
	return cards


func _encode_card_array(values: Array) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for value in values:
		var card_data := value as CardData
		if card_data == null:
			continue
		cards.append(CardSnapshot.serialize_card_data(card_data))
	return cards


func _decode_card_snapshot_array(values: Variant) -> Array[CardSnapshot]:
	var snapshots: Array[CardSnapshot] = []
	if typeof(values) != TYPE_ARRAY:
		return snapshots
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var snapshot := CardSnapshot.from_serialized_dict(value)
		if snapshot != null:
			snapshots.append(snapshot)
	return snapshots


func _encode_card_snapshot_array(values: Array) -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for value in values:
		var snapshot := value as CardSnapshot
		if snapshot == null:
			continue
		encoded.append(CardSnapshot.to_serialized_dict(snapshot))
	return encoded


func _decode_card_snapshot(data: Dictionary) -> CardSnapshot:
	return CardSnapshot.from_serialized_dict(data)


func _encode_card_snapshot(snapshot: CardSnapshot) -> Dictionary:
	return CardSnapshot.to_serialized_dict(snapshot)


func _decode_card_data(data: Dictionary) -> CardData:
	return CardSnapshot.deserialize_card_data(data)


func _encode_card_data(card_data: CardData) -> Dictionary:
	return CardSnapshot.serialize_card_data(card_data)


func _decode_card_action_array(values: Variant) -> Array[CardAction]:
	var actions: Array[CardAction] = []
	if typeof(values) != TYPE_ARRAY:
		return actions
	for value in values:
		var action := _decode_scripted_resource(value) as CardAction
		if action != null:
			actions.append(action)
	return actions


func _encode_scripted_resource(resource: Resource) -> Dictionary:
	if resource == null:
		return {}
	var script := resource.get_script() as Script
	if script == null:
		push_warning("SaveService: missing script for resource class=%s" % resource.get_class())
		return {}
	var script_uid := _script_uid_for_script(script)
	if script_uid.is_empty():
		push_warning("SaveService: missing script uid for %s" % str(script.resource_path))
		return {}
	return {
		"script_uid": script_uid,
		"values": _encode_resource_values(resource),
	}


func _decode_scripted_resource(value: Variant) -> Resource:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var data := value as Dictionary
	var script_uid := str(data.get("script_uid", ""))
	if script_uid.is_empty():
		push_warning("SaveService: scripted resource is missing script_uid")
		return null
	var script_path := _script_path_for_uid(script_uid)
	if script_path.is_empty():
		push_warning("SaveService: unable to resolve script uid %s" % script_uid)
		return null
	var script := load(script_path) as Script
	if script == null:
		push_warning("SaveService: failed to load script at %s" % script_path)
		return null
	var resource = script.new()
	if !(resource is Resource):
		push_warning("SaveService: script %s did not instantiate a Resource" % script_path)
		return null
	_apply_decoded_resource_values(resource, _as_dictionary(data.get("values", {})))
	return resource


func _encode_resource_values(resource: Resource) -> Dictionary:
	var values := {}
	for property_data in resource.get_property_list():
		if !_should_encode_resource_property(property_data):
			continue
		var property_name := str(property_data.name)
		values[property_name] = _encode_variant_value(resource.get(property_name))
	return values


func _apply_decoded_resource_values(resource: Resource, values: Dictionary) -> void:
	for key in values.keys():
		var property_name := str(key)
		if !_resource_has_property(resource, property_name):
			continue
		resource.set(property_name, _decode_variant_value(values[key]))


func _resource_has_property(resource: Resource, property_name: String) -> bool:
	if resource == null or property_name.is_empty():
		return false
	for property_data in resource.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			return true
	return false


func _should_encode_resource_property(property_data: Dictionary) -> bool:
	var property_name := str(property_data.get("name", ""))
	if property_name.is_empty():
		return false
	if property_name == "metadata/_custom_type_script":
		return false
	if property_name in ["resource_local_to_scene", "resource_name", "resource_path", "resource_scene_unique_id", "script"]:
		return false
	var usage := int(property_data.get("usage", 0))
	if (usage & PROPERTY_USAGE_STORAGE) == 0:
		return false
	return true


func _encode_variant_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return {
				"__kind": SERIALIZED_KIND_STRING_NAME,
				"value": str(value),
			}
		TYPE_COLOR:
			var color := value as Color
			return {
				"__kind": SERIALIZED_KIND_COLOR,
				"r": color.r,
				"g": color.g,
				"b": color.b,
				"a": color.a,
			}
		TYPE_VECTOR2:
			var vector2 := value as Vector2
			return {
				"__kind": SERIALIZED_KIND_VECTOR2,
				"x": float(vector2.x),
				"y": float(vector2.y),
			}
		TYPE_VECTOR2I:
			var vector2i := value as Vector2i
			return {
				"__kind": SERIALIZED_KIND_VECTOR2I,
				"x": int(vector2i.x),
				"y": int(vector2i.y),
			}
		TYPE_VECTOR3:
			var vector3 := value as Vector3
			return {
				"__kind": SERIALIZED_KIND_VECTOR3,
				"x": float(vector3.x),
				"y": float(vector3.y),
				"z": float(vector3.z),
			}
		TYPE_ARRAY:
			var encoded_array: Array = []
			for entry in value:
				encoded_array.append(_encode_variant_value(entry))
			return encoded_array
		TYPE_DICTIONARY:
			var encoded_dict := {}
			for key in value.keys():
				encoded_dict[str(key)] = _encode_variant_value(value[key])
			return encoded_dict
		TYPE_PACKED_STRING_ARRAY:
			return {
				"__kind": SERIALIZED_KIND_PACKED_STRING_ARRAY,
				"values": _encode_packed_string_array(value),
			}
		TYPE_PACKED_INT32_ARRAY:
			return {
				"__kind": SERIALIZED_KIND_PACKED_INT32_ARRAY,
				"values": _encode_int_array(value),
			}
		TYPE_OBJECT:
			if value is Resource:
				var resource := value as Resource
				if _should_store_resource_as_reference(resource):
					return {
						"__kind": SERIALIZED_KIND_EXTERNAL_RESOURCE,
						"path": _external_resource_ref_string(resource),
					}
				return {
					"__kind": SERIALIZED_KIND_SCRIPTED_RESOURCE,
					"data": _encode_scripted_resource(resource),
				}
	push_warning("SaveService: unsupported save variant type %s" % typeof(value))
	return null


func _decode_variant_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var decoded_array: Array = []
		for entry in value:
			decoded_array.append(_decode_variant_value(entry))
		return decoded_array
	if typeof(value) != TYPE_DICTIONARY:
		return value

	var dict := value as Dictionary
	var kind := str(dict.get("__kind", ""))
	match kind:
		"":
			var decoded_dict := {}
			for key in dict.keys():
				decoded_dict[str(key)] = _decode_variant_value(dict[key])
			return decoded_dict
		SERIALIZED_KIND_STRING_NAME:
			return StringName(str(dict.get("value", "")))
		SERIALIZED_KIND_COLOR:
			return Color(
				float(dict.get("r", 1.0)),
				float(dict.get("g", 1.0)),
				float(dict.get("b", 1.0)),
				float(dict.get("a", 1.0))
			)
		SERIALIZED_KIND_VECTOR2:
			return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
		SERIALIZED_KIND_VECTOR2I:
			return Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
		SERIALIZED_KIND_VECTOR3:
			return Vector3(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)), float(dict.get("z", 0.0)))
		SERIALIZED_KIND_PACKED_STRING_ARRAY:
			return _decode_packed_string_array(dict.get("values", []))
		SERIALIZED_KIND_PACKED_INT32_ARRAY:
			return PackedInt32Array(_decode_int_array(dict.get("values", [])))
		SERIALIZED_KIND_EXTERNAL_RESOURCE:
			return _load_external_resource_ref(str(dict.get("path", "")))
		SERIALIZED_KIND_SCRIPTED_RESOURCE:
			return _decode_scripted_resource(dict.get("data", {}))
	return dict


func _should_store_resource_as_reference(resource: Resource) -> bool:
	if resource == null:
		return true
	return !str(resource.resource_path).is_empty() or resource.get_script() == null or resource is Sound or resource is PackedScene


func _external_resource_ref_string(resource: Resource) -> String:
	if resource == null:
		return ""
	var path := str(resource.resource_path)
	if path.is_empty():
		return ""
	if path.begins_with("uid://"):
		return path
	var uid := ResourceLoader.get_resource_uid(path)
	if uid > 0:
		return ResourceUID.id_to_text(uid)
	return path


func _load_external_resource_ref(path: String) -> Resource:
	if path.is_empty():
		return null
	var resource := load(path) as Resource
	if resource == null:
		push_warning("SaveService: failed to load external resource %s" % path)
	return resource


func _script_uid_for_script(script: Script) -> String:
	if script == null:
		return ""
	var uid_path := "%s.uid" % str(script.resource_path)
	if !FileAccess.file_exists(uid_path):
		return ""
	var file := FileAccess.open(uid_path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()


func _script_path_for_uid(script_uid: String) -> String:
	if script_uid.is_empty():
		return ""
	_ensure_script_uid_cache()
	return str(_script_uid_path_cache.get(script_uid, ""))


func _ensure_script_uid_cache() -> void:
	if _script_uid_cache_ready:
		return
	_script_uid_cache_ready = true
	_index_script_uid_dir("res://")


func _index_script_uid_dir(local_dir: String) -> void:
	var dir := DirAccess.open(ProjectSettings.globalize_path(local_dir))
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while !entry.is_empty():
		var child_path := _join_local_path(local_dir, entry)
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				_index_script_uid_dir(child_path)
		elif entry.ends_with(".gd.uid"):
			var file := FileAccess.open(child_path, FileAccess.READ)
			if file != null:
				var uid_text := file.get_as_text().strip_edges()
				if !uid_text.is_empty():
					_script_uid_path_cache[uid_text] = child_path.trim_suffix(".uid")
		entry = dir.get_next()
	dir.list_dir_end()


func _join_local_path(base_path: String, child: String) -> String:
	if base_path.ends_with("://"):
		return "%s%s" % [base_path, child]
	if base_path.ends_with("/"):
		return "%s%s" % [base_path, child]
	return "%s/%s" % [base_path, child]


func _decode_vector2i(value: Variant, default_value: Vector2i = Vector2i.ZERO) -> Vector2i:
	if typeof(value) != TYPE_ARRAY:
		return default_value
	var values: Array = value
	if values.size() != 2:
		return default_value
	return Vector2i(int(values[0]), int(values[1]))


func _encode_vector2i(value: Vector2i) -> Array[int]:
	return [int(value.x), int(value.y)]


func _decode_vector2i_array(value: Variant) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if typeof(value) != TYPE_ARRAY:
		return coords
	for entry in value:
		coords.append(_decode_vector2i(entry, Vector2i.ZERO))
	return coords


func _encode_vector2i_array(values: Array[Vector2i]) -> Array[Array]:
	var encoded: Array[Array] = []
	for value in values:
		encoded.append(_encode_vector2i(value))
	return encoded


func _decode_int_array(value: Variant) -> Array[int]:
	var ints: Array[int] = []
	if typeof(value) != TYPE_ARRAY:
		return ints
	for entry in value:
		ints.append(int(entry))
	return ints


func _encode_int_array(values: Array[int]) -> Array[int]:
	var ints: Array[int] = []
	for value in values:
		ints.append(int(value))
	return ints


func _decode_packed_string_array(value: Variant) -> PackedStringArray:
	var strings := PackedStringArray()
	if typeof(value) != TYPE_ARRAY:
		return strings
	for entry in value:
		strings.append(str(entry))
	return strings


func _encode_packed_string_array(values: PackedStringArray) -> Array[String]:
	var strings: Array[String] = []
	for value in values:
		strings.append(str(value))
	return strings


func _decode_string_dictionary(value: Variant) -> Dictionary:
	var decoded := {}
	if typeof(value) != TYPE_DICTIONARY:
		return decoded
	var raw := value as Dictionary
	for key in raw.keys():
		decoded[str(key)] = str(raw[key])
	return decoded


func _encode_string_dictionary(values: Dictionary) -> Dictionary:
	var encoded := {}
	for key in values.keys():
		encoded[str(key)] = str(values[key])
	return encoded


func _as_dictionary(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _normalize_active_run(run_state: RunState) -> void:
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
	if run_state.draftable_cards == null:
		run_state.draftable_cards = CardPile.new()
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
	if run_state.battle_assignments_by_room_key == null:
		run_state.battle_assignments_by_room_key = {}
	if int(run_state.map_seed) == 0:
		run_state.map_seed = RNGUtil.seed_from_label(int(run_state.run_seed), "map")
	if run_state.run_rng_snapshot == null:
		run_state.run_rng_snapshot = {}
	if run_state.owned_arcanum_ids == null:
		run_state.owned_arcanum_ids = PackedStringArray()
	if run_state.consumed_battle_paths == null:
		run_state.consumed_battle_paths = PackedStringArray()
	_remove_pending_room_from_cleared(run_state)


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


func _build_debug_run_info_from_path(slot_key: String, file_name: String, path: String) -> DebugRunSaveInfo:
	var envelope := _read_json_file(path)
	var data := _extract_envelope_data(envelope, FILE_TYPE_RUN)
	if data.is_empty():
		return null
	var info := DebugRunSaveInfo.new()
	info.slot_key = slot_key
	info.file_name = file_name
	info.modified_unix_time = int(FileAccess.get_modified_time(ProjectSettings.globalize_path(path)))
	var display_name := str(data.get("save_name", "")).strip_edges()
	info.display_name = display_name if !display_name.is_empty() else slot_key
	info.player_profile_id = str(data.get("player_profile_id", ""))
	info.gold = int(data.get("gold", 0))
	return info
