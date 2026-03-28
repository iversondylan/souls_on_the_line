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
	if String(migrated.player_profile_id).is_empty():
		push_warning("SaveService: active run is missing player_profile_id; clearing incompatible save")
		clear_active_run()
		return null
	if needs_resave:
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
