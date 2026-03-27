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


func load_active_run() -> RunState:
	var loaded := _load_resource(ACTIVE_RUN_SAVE_PATH)
	if loaded == null:
		return null

	var migrated := _normalize_active_run(loaded)
	if migrated == null:
		return null
	if loaded is RunAccount:
		save_active_run(migrated)
	return migrated


func save_active_run(run_state: RunState) -> bool:
	if run_state == null:
		return false
	return _save_resource(run_state, ACTIVE_RUN_SAVE_PATH)


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

func _normalize_active_run(resource: Resource) -> RunState:
	var run_state: RunState = null
	if resource is RunAccount:
		var legacy := resource as RunAccount
		run_state = RunState.new()
		run_state.gold = legacy.gold
		run_state.card_reward_choices = legacy.card_reward_choices
		run_state.common_weight = legacy.common_weight
		run_state.uncommon_weight = legacy.uncommon_weight
		run_state.rare_weight = legacy.rare_weight
		run_state.run_seed = legacy.run_seed
		run_state.player_data = legacy.player_data if legacy.player_data != null else legacy.player_definition
		run_state.player_run_state = legacy.player_run_state
		run_state.cleared_room_coords = legacy.cleared_room_coords
		run_state.location_kind = legacy.location_kind
		run_state.pending_room_coord = legacy.pending_room_coord
		run_state.owned_arcanum_ids = legacy.owned_arcanum_ids
		run_state.draftable_cards = legacy.draftable_cards
		run_state.run_deck = legacy.run_deck
	elif resource is RunState:
		run_state = resource as RunState
	else:
		return null

	if run_state.player_run_state == null:
		run_state.player_run_state = PlayerRunState.new()
	if run_state.player_data == null and resource is RunAccount:
		run_state.player_data = (resource as RunAccount).player_definition
	if run_state.run_deck == null:
		run_state.run_deck = RunDeck.new()
	if run_state.run_deck.card_collection == null:
		run_state.run_deck.card_collection = CardPile.new()
	if run_state.owned_arcanum_ids == null:
		run_state.owned_arcanum_ids = PackedStringArray()
	return run_state
