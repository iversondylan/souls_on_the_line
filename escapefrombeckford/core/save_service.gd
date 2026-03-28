extends Node

const PROFILE_SAVE_PATH := "user://profile_data.tres"
const ACTIVE_RUN_SAVE_PATH := "user://active_run.tres"
const LEGACY_SAVE_PATH_REPLACEMENTS := {
	"res://custom_resources/profile_data.gd": "res://run/state/profile_data.gd",
	"res://custom_resources/soul_recess_state.gd": "res://run/state/soul_recess_state.gd",
	"res://custom_resources/card_snapshot.gd": "res://cards/core/card_snapshot.gd",
	"res://custom_resources/run_account.gd": "res://run/state/run_account.gd",
	"res://custom_resources/run_state.gd": "res://run/state/run_state.gd",
	"res://custom_resources/player_run_state.gd": "res://run/state/player_run_state.gd",
	"res://custom_resources/player_data.gd": "res://character_profiles/player_data.gd",
	"res://custom_resources/card_pile.gd": "res://cards/core/card_pile.gd",
	"res://custom_resources/card_data.gd": "res://cards/core/card_data.gd",
	"res://scenes/run_deck.gd": "res://run/state/run_deck.gd",
}

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
	var needs_resave := false
	if loaded is RunState:
		var loaded_run := loaded as RunState
		needs_resave = loaded_run.player_data != null \
			or String(loaded_run.player_profile_id).is_empty() \
			or int(loaded_run.map_seed) == 0 \
			or loaded_run.player_run_state == null \
			or int(loaded_run.player_run_state.max_health) <= 0 \
			or _pending_room_in_cleared(loaded_run)

	var migrated := _normalize_active_run(loaded)
	if migrated == null:
		return null
	if needs_resave:
		save_active_run(migrated)
	return migrated


func save_active_run(run_state: RunState) -> bool:
	if run_state == null:
		return false
	run_state.player_data = null
	return _save_resource(run_state, ACTIVE_RUN_SAVE_PATH)


func _load_resource(path: String) -> Resource:
	if !FileAccess.file_exists(path):
		return null
	_migrate_legacy_save_paths(path)
	return ResourceLoader.load(path) # oops I moved stuff around now this was called with a bad path


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
	if resource is RunState:
		run_state = resource as RunState
	else:
		return null

	if run_state.player_run_state == null:
		run_state.player_run_state = PlayerRunState.new()
	if run_state.player_profile_id.is_empty() and run_state.player_data != null:
		run_state.player_profile_id = _derive_player_profile_id(run_state.player_data)
	if int(run_state.player_run_state.max_health) <= 0 and run_state.player_data != null:
		run_state.player_run_state.max_health = maxi(int(run_state.player_data.max_health), 0)
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
	run_state.player_data = null
	return run_state


func _derive_player_profile_id(player_data: PlayerData) -> String:
	if player_data == null:
		return ""
	if !String(player_data.profile_id).is_empty():
		return String(player_data.profile_id)
	if !String(player_data.resource_path).is_empty():
		var file_name := player_data.resource_path.get_file().get_basename()
		if file_name.ends_with("_data"):
			file_name = file_name.trim_suffix("_data")
		return file_name.to_lower()
	return ""


func _migrate_legacy_save_paths(path: String) -> void:
	if !path.ends_with(".tres") and !path.ends_with(".tscn"):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var contents := file.get_as_text()
	file.close()

	var migrated := contents
	for from_path in LEGACY_SAVE_PATH_REPLACEMENTS:
		migrated = migrated.replace(from_path, LEGACY_SAVE_PATH_REPLACEMENTS[from_path])

	if migrated == contents:
		return

	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: failed to rewrite legacy save paths for %s" % path)
		return
	file.store_string(migrated)
	file.close()


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
