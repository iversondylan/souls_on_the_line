# run.gd

class_name Run
extends Node

const BATTLE_SCN := preload("uid://k11cug4p8o3l")
const BATTLE_REWARDS_SCN := preload("uid://dg2swwanmuywt")
const CAMPFIRE_SCN := preload("uid://cc8jy5tcqxyuv")
const MAIN_MENU_SCN := preload("uid://byfyjsj2j7wh")
#const MAP_SCENE := preload("uid://6p15tduy6cd2")
const SHOP_SCN := preload("uid://csf5mgsw4psnr")
const TREASURE_SCN := preload("uid://c4tto5c3yx2dt")
const RUN_SAVE_PICKER_SCN := preload("res://ui/run_save_picker.tscn")
const SAVE_NAME_DIALOG_SCN := preload("res://ui/save_name_dialog.tscn")


@export var player_catalog: PlayerCatalog = preload("uid://b2ewfy12rhm0l")
@export var status_catalog: StatusCatalog
@export var arcanum_catalog: ArcanaCatalog
@export var battle_pool: BattlePool
@export var tutorial_encounter: BattleData
@export var tutorial_player_data: PlayerData
@export_range(1, 99, 1) var soulbound_slot_count: int = RunDeck.DEFAULT_SOULBOUND_SLOT_COUNT

# TEMPORARY v
#@export var extra_arcana: Array[Arcanum]
# TEMPORARY ^

@onready var map: Map = $Map

@onready var current_view: Node = $CurrentView
@onready var gold_display: GoldDisplay = %GoldDisplay
#@onready var arcana_system: ArcanaSystem = %ArcanaSystem
@onready var arcana_system_container: ArcanaSystemContainer = %ArcanaSystemContainer

@onready var collection_button: CardPileOpener = %CollectionButton
@onready var collection_pile_view: CardPileView = %CollectionPileView
@onready var arcanum_tooltip_popup: ArcanumTooltipPopup = %ArcanumTooltipPopup
@onready var pause_menu: Control = $UI/PauseMenu
@onready var resume_game_button: Button = $UI/PauseMenu/PanelContainer/MarginContainer/Content/Buttons/ResumeGameButton
@onready var return_to_main_menu_button: Button = $UI/PauseMenu/PanelContainer/MarginContainer/Content/Buttons/ReturnToMainMenuButton
@onready var pause_debug_buttons: Control = $UI/PauseMenu/PanelContainer/MarginContainer/Content/DebugButtons
@onready var pause_debug_save_button: Button = $UI/PauseMenu/PanelContainer/MarginContainer/Content/DebugButtons/DebugSaveButton
@onready var pause_debug_load_button: Button = $UI/PauseMenu/PanelContainer/MarginContainer/Content/DebugButtons/DebugLoadButton
@onready var debug_ui: CanvasLayer = $DebugUI

@onready var map_button: Button = %MapButton
@onready var battle_button: Button = %BattleButton
@onready var shop_button: Button = %ShopButton
@onready var treasure_button: Button = %TreasureButton
@onready var rewards_button: Button = %RewardsButton
@onready var campfire_button: Button = %CampfireButton
@onready var health_panel: HealthBar = $UI/TopBarItems/HealthPanel

var run_state: RunState
var profile_data: ProfileData
var player_data: PlayerData
var run_seed: int = 0
var arcana_system: ArcanaSystem
var arcana_catalog: ArcanaCatalog
var draftable_cards: CardPile
var run_deck: RunDeck
var run_rng: RunRNG
var startup_mode: int = -1
var run_save_picker: RunSavePicker
var save_name_dialog: SaveNameDialog
var collection_display_pile: CardPile = CardPile.new()
var _pending_launch_signature_soul: CardData
var _has_pending_launch_signature_payload: bool = false
var _launch_has_soulbound_roster: bool = true


func _ready() -> void:
	#print_tree_pretty()
	status_catalog.build_index()
	arcanum_catalog.build_index()
	if player_catalog != null:
		player_catalog.build_index()
	arcana_system = arcana_system_container.system
	_ensure_debug_tools()
	pause_menu.visible = false
	_refresh_debug_ui()
	resume_game_button.pressed.connect(_close_pause_menu)
	return_to_main_menu_button.pressed.connect(_return_to_main_menu_from_pause)
	pause_debug_save_button.pressed.connect(_on_pause_debug_save_pressed)
	pause_debug_load_button.pressed.connect(_on_pause_debug_load_pressed)

	var run_profile := Autoload.consume_run_profile_or_default()
	if run_profile == null:
		push_warning("Run._ready(): opened without a pending RunProfile.")
		return

	profile_data = SaveService.load_or_create_profile()
	if profile_data == null:
		push_warning("Run._ready(): opened without an active user profile.")
		get_tree().change_scene_to_packed(MAIN_MENU_SCN)
		return
	_launch_has_soulbound_roster = bool(run_profile.has_soulbound_roster)
	startup_mode = int(run_profile.start_mode)
	match int(run_profile.start_mode):
		RunProfile.StartMode.NEW_RUN:
			_start_new_run_from_profile(run_profile)
		RunProfile.StartMode.CONTINUE_RUN:
			_continue_saved_run()
		RunProfile.StartMode.LOAD_DEBUG_SLOT:
			_load_debug_slot_run(run_profile.debug_slot_name)
		RunProfile.StartMode.TUTORIAL:
			_start_new_run_from_profile(run_profile)
		_:
			push_warning("Run._ready(): unknown RunProfile.start_mode '%s'" % run_profile.start_mode)

func _start_run() -> void:
	_prepare_run_runtime()
	_generate_or_restore_map()
	_persist_active_run()

func _start_tutorial_run() -> void:
	_prepare_run_runtime()
	if tutorial_encounter == null:
		push_warning("Run._start_tutorial_run(): tutorial_encounter is not assigned.")
		get_tree().change_scene_to_packed(MAIN_MENU_SCN)
		return
	_start_direct_battle(tutorial_encounter, "tutorial_battle")

func _prepare_run_runtime() -> void:
	if run_state == null:
		run_state = RunState.new()
	run_state.draftable_cards = draftable_cards
	if run_state.run_deck == null:
		if run_deck == null:
			run_deck = RunDeck.new()
		run_deck.has_soulbound_roster = _launch_has_soulbound_roster
		run_deck.soulbound_slot_count = soulbound_slot_count
		if run_deck.card_collection == null and player_data != null and player_data.starting_deck != null:
			run_deck.card_collection = player_data.starting_deck
		if run_deck.has_soulbound_roster_enabled() and run_deck.get_soulbound_slot_cards().is_empty() and player_data != null:
			run_deck.initialize_soulbound_slots(null, _get_player_starter_soul())
		run_state.run_deck = run_deck
	else:
		run_deck = run_state.run_deck
	_configure_run_deck()
	
	##This is for messing around with extra starting gold
	if startup_mode == int(RunProfile.StartMode.NEW_RUN) or startup_mode == int(RunProfile.StartMode.TUTORIAL):
		run_state.gold += player_data.bonus_starting_gold
	_ensure_player_run_state_initialized()
	
	_connect_signals()
	_init_top_bar()

func _change_view(scene: PackedScene) -> Node:
	_force_close_pause_menu()
	arcana_system_container.reset_display_stacks()
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	get_tree().paused = false
	var new_view := scene.instantiate()
	current_view.add_child(new_view)
	map.hide_map()
	
	return new_view



func _show_map() -> void:
	_force_close_pause_menu()
	arcana_system_container.reset_display_stacks()
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	map.show_map()
	if map.last_room == null:
		map.unlock_encounter_column(0)
	else:
		map.unlock_next_rooms()
	_set_location_map()
	_refresh_top_bar_health()
	_persist_active_run()

func _connect_signals() -> void:
	Events.battle_won.connect(_on_battle_won)
	Events.battle_rewards_exited.connect(_on_pending_room_exited_to_map)
	Events.campfire_exited.connect(_on_pending_room_exited_to_map)
	Events.map_exited.connect(_on_map_exited)
	Events.shop_exited.connect(_on_pending_room_exited_to_map)
	Events.treasure_room_exited.connect(_on_treasure_room_exited)
	Events.player_battle_health_changed.connect(_on_player_battle_health_changed)
	Events.request_defeat.connect(_on_run_defeat)
	
	battle_button.pressed.connect(_change_view.bind(BATTLE_SCN))
	campfire_button.pressed.connect(_change_view.bind(CAMPFIRE_SCN))
	map_button.pressed.connect(_show_map)
	rewards_button.pressed.connect(_change_view.bind(BATTLE_REWARDS_SCN))
	shop_button.pressed.connect(_on_shop_entered)
	treasure_button.pressed.connect(_on_treasure_room_entered)

func _init_top_bar() -> void:
	health_panel.update_health_view(_get_current_run_max_health(), _get_current_run_health())
	gold_display.run_state = run_state
	
	_clear_run_arcana()
	if run_state != null and !run_state.owned_arcanum_ids.is_empty():
		for arcanum_id in run_state.owned_arcanum_ids:
			var proto := arcanum_catalog.get_proto(StringName(arcanum_id))
			if proto != null:
				arcana_system_container.add_arcanum(proto)
	elif player_data != null and player_data.starting_arcanum != null:
		arcana_system_container.add_arcanum(player_data.starting_arcanum)
	
# TEMPORARY v
	#if run_state != null and run_state.owned_arcanum_ids.is_empty():
		#for arcanum: Arcanum in extra_arcana:
			#arcana_system_container.add_arcana([arcanum])
# TEMPORARY ^

	_refresh_collection_display_pile()
	collection_button.card_pile = collection_display_pile
	collection_pile_view.card_pile = collection_display_pile
	collection_pile_view.player_data = player_data
	var show_collection_callable := collection_pile_view.show_current_view.bind("Collection")
	if !collection_button.pressed.is_connected(show_collection_callable):
		collection_button.pressed.connect(show_collection_callable)

func _on_battle_entered(room: Room) -> void:
	_on_battle_entered_with_seed(room, -1)


func _on_battle_entered_with_seed(room: Room, existing_battle_seed: int = -1) -> void:
	if !_ensure_room_entry_allowed(room, "_on_battle_entered_with_seed"):
		return
	_assign_battle_to_room_if_needed(room)
	var label := "room:%d:%d:battle_seed" % [room.row, room.column]
	var battle_seed := int(existing_battle_seed)
	if battle_seed < 0:
		var rng := run_rng.get_stream(label)
		# simplest: battle_seed is first randi from this room stream
		battle_seed = int(rng.randi())
		run_rng.commit(rng)
	#print("[Run] battle_seed for (%d,%d) = %d" % [room.row, room.column, battle_seed])
	map.set_active_room(room)
	_set_location_for_room(room)
	run_state.pending_battle_seed = battle_seed
	_persist_active_run()
	var battle_scn: Battle = _change_view(BATTLE_SCN) as Battle
	battle_scn.run_seed = run_seed
	battle_scn.battle_seed = battle_seed
	battle_scn.run = self
	battle_scn.run_state = run_state
	battle_scn.player_data = player_data
	battle_scn.run_deck = run_deck
	battle_scn.battle_data = room.battle_data
	#battle_scn.arcana = arcana_system_container.system
	battle_scn.my_arcana = arcana_system.get_my_arcana()
	battle_scn.start_battle()

func _start_direct_battle(selected_battle_data: BattleData, seed_label: String) -> void:
	var direct_battle_seed := RNGUtil.seed_from_label(run_seed, seed_label)
	var battle_scn: Battle = _change_view(BATTLE_SCN) as Battle
	battle_scn.run_seed = run_seed
	battle_scn.battle_seed = direct_battle_seed
	battle_scn.run = self
	battle_scn.run_state = run_state
	battle_scn.player_data = player_data
	battle_scn.run_deck = run_deck
	battle_scn.battle_data = selected_battle_data
	battle_scn.my_arcana = arcana_system.get_my_arcana()
	battle_scn.start_battle()

func _on_rest_site_entered(room: Room = map.last_room) -> void:
	if !_ensure_room_entry_allowed(room, "_on_rest_site_entered"):
		return
	map.set_active_room(room)
	_set_location_for_room(room)
	if int(run_state.pending_room_seed) == 0:
		run_state.pending_room_seed = _derive_room_seed(room, "rest")
	_persist_active_run()
	var campfire := _change_view(CAMPFIRE_SCN) as Campfire
	campfire.configure(run_state, profile_data, run_deck)

func _on_shop_entered(room: Room = map.last_room) -> void:
	if !_ensure_room_entry_allowed(room, "_on_shop_entered"):
		return
	map.set_active_room(room)
	_set_location_for_room(room)
	_build_pending_shop_checkpoint(room)
	_persist_active_run()
	var shop := _change_view(SHOP_SCN) as Shop
	shop.run = self
	shop.player_data = player_data
	shop.run_state = run_state
	shop.arcana_system = arcana_system
	shop.arcana_system_container = arcana_system_container
	shop.arcana_catalog = arcana_catalog
	shop.arcana_reward_pool = player_data.arcana_reward_pool
	var shop_ctx := _build_pending_shop_context()
	shop.populate_from_context(shop_ctx)

func _on_battle_won() -> void:
	if _is_tutorial_mode():
		_exit_tutorial_to_main_menu()
		return
	_sync_player_health_from_active_battle()
	_prepare_pending_reward_checkpoint(int(RewardContext.SourceKind.BATTLE), map.last_room)
	_persist_active_run()
	_open_pending_reward_screen()

func _on_treasure_room_entered(room: Room = map.last_room) -> void:
	if !_ensure_room_entry_allowed(room, "_on_treasure_room_entered"):
		return
	map.set_active_room(room)
	_set_location_for_room(room)
	_build_pending_treasure_checkpoint(room)
	_persist_active_run()
	var treasure_scn := _change_view(TREASURE_SCN) as TreasureRoom
	treasure_scn.player_data = player_data
	treasure_scn.set_found_arcanum(_resolve_pending_treasure_arcanum())

func _on_treasure_room_exited(arcanum: Arcanum) -> void:
	if arcanum != null and run_state != null and run_state.pending_treasure_arcanum_id.is_empty():
		run_state.pending_treasure_arcanum_id = String(arcanum.get_id())
	_prepare_pending_reward_checkpoint(int(RewardContext.SourceKind.TREASURE), map.last_room)
	_persist_active_run()
	_open_pending_reward_screen()

func _on_map_exited(room: Room) -> void:
	if !_ensure_room_entry_allowed(room, "_on_map_exited"):
		return
	match room.type:
		Room.RoomType.BATTLE:
			_on_battle_entered(room)
		Room.RoomType.TREASURE:
			_on_treasure_room_entered(room)
		Room.RoomType.REST:
			_on_rest_site_entered(room)
		Room.RoomType.SHOP:
			_on_shop_entered(room)
		Room.RoomType.BOSS:
			_on_battle_entered(room)


func _start_new_run_from_profile(profile: RunProfile) -> void:
	run_seed = profile.seed
	if run_seed == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		run_seed = int(rng.randi())
	#print("run.gd new run startup seed: ", run_seed)
	run_rng = RunRNG.new(run_seed)

	player_data = _resolve_starting_player_data(profile.player_profile_id)
	if player_data == null:
		push_warning("Run._start_new_run_from_profile(): no player profile found for id '%s'" % profile.player_profile_id)
		return

	var starting_deck := player_data.starting_deck
	draftable_cards = player_data.draftable_cards.duplicate()

	var signature_soulbound_card: CardData = null
	if bool(profile.has_soulbound_roster):
		if profile.selected_signature_soul_serialized.is_empty():
			push_warning("Run._start_new_run_from_profile(): RunProfile signature soul payload is empty; falling back to selected_starting_soul_uid resolution.")
		signature_soulbound_card = profile.instantiate_selected_signature_soul()
		if !profile.selected_signature_soul_serialized.is_empty() and signature_soulbound_card == null:
			push_warning("Run._start_new_run_from_profile(): RunProfile signature soul payload is invalid; falling back to selected_starting_soul_uid resolution.")
		if signature_soulbound_card == null:
			signature_soulbound_card = _resolve_profile_signature_soul(profile.selected_starting_soul_uid)
			_has_pending_launch_signature_payload = false
			_pending_launch_signature_soul = null
		else:
			_has_pending_launch_signature_payload = !profile.selected_signature_soul_serialized.is_empty()
			_pending_launch_signature_soul = signature_soulbound_card.make_runtime_instance()
	else:
		_has_pending_launch_signature_payload = false
		_pending_launch_signature_soul = null

	arcana_catalog = arcanum_catalog.duplicate()
	run_state = RunState.new()
	run_state.run_seed = run_seed
	run_state.map_seed = RNGUtil.seed_from_label(run_seed, "map")
	run_state.run_rng_snapshot = run_rng.snapshot()
	run_state.player_profile_id = String(player_data.profile_id)
	run_state.player_run_state = PlayerRunState.new()
	run_state.player_run_state.initialize_from_player_data(player_data)
	run_state.owned_arcanum_ids = PackedStringArray([String(player_data.starting_arcanum.get_id())]) if player_data.starting_arcanum != null else PackedStringArray()
	run_deck = RunDeck.new()
	run_deck.has_soulbound_roster = bool(profile.has_soulbound_roster)
	run_deck.soulbound_slot_count = soulbound_slot_count
	run_deck.card_collection = starting_deck
	if run_deck.has_soulbound_roster_enabled():
		run_deck.initialize_soulbound_slots(signature_soulbound_card, _get_player_starter_soul())
	else:
		run_deck.initialize_soulbound_slots(null, null)
	run_state.run_deck = run_deck
	# TEMPORARY v
	#for arcanum in extra_arcana:
		#if arcanum != null:
			#run_state.owned_arcanum_ids.append(String(arcanum.get_id()))
	# TEMPORARY ^
	#print("run.gd STARTING RUN WITH NEW CHARACTER")
	SaveService.save_profile(profile_data)
	if startup_mode == int(RunProfile.StartMode.TUTORIAL):
		_start_tutorial_run()
		return
	_start_run()


func _resolve_starting_player_data(profile_id: String) -> PlayerData:
	if _is_tutorial_mode() and tutorial_player_data != null:
		return tutorial_player_data
	return _resolve_player_profile(profile_id)


func _get_player_starter_soul() -> CardData:
	if player_data == null:
		return null
	return player_data.starter_soul


func _resolve_profile_signature_soul(selected_uid: String) -> CardData:
	var starter_soul := _get_player_starter_soul()
	if profile_data == null or profile_data.soul_recess_state == null:
		return starter_soul.make_runtime_instance() if starter_soul != null else null
	return profile_data.soul_recess_state.resolve_selected_signature_soul_card(selected_uid, starter_soul)


func _continue_saved_run() -> void:
	var loaded_run_state := SaveService.load_active_run()
	if loaded_run_state == null:
		push_warning("Run._continue_saved_run(): no active run save found")
		return
	_boot_from_loaded_run_state(loaded_run_state)


func _load_debug_slot_run(slot_name: String) -> void:
	var loaded_run_state := SaveService.load_debug_run(slot_name)
	if loaded_run_state == null:
		push_warning("Run._load_debug_slot_run(): no debug save found for slot '%s'" % slot_name)
		get_tree().change_scene_to_packed(MAIN_MENU_SCN)
		return
	_boot_from_loaded_run_state(loaded_run_state)


func _boot_from_loaded_run_state(loaded_run_state: RunState) -> void:
	run_state = loaded_run_state
	player_data = _resolve_player_profile(run_state.player_profile_id)
	if player_data == null:
		push_warning("Run._boot_from_loaded_run_state(): unknown player_profile_id '%s'" % run_state.player_profile_id)
		return
	if run_state.player_profile_id.is_empty():
		run_state.player_profile_id = String(player_data.profile_id)
	_ensure_player_run_state_initialized()

	draftable_cards = run_state.draftable_cards if run_state.draftable_cards != null else player_data.draftable_cards.duplicate()
	run_deck = run_state.run_deck if run_state.run_deck != null else RunDeck.new()
	if run_state.run_deck == null:
		run_deck.has_soulbound_roster = _launch_has_soulbound_roster
	run_deck.soulbound_slot_count = soulbound_slot_count
	if run_deck.card_collection == null:
		run_deck.card_collection = player_data.starting_deck
	if run_deck.has_soulbound_roster_enabled() and run_deck.get_soulbound_slot_cards().is_empty():
		run_deck.initialize_soulbound_slots(null, _get_player_starter_soul())
	_configure_run_deck()
	run_seed = int(run_state.run_seed)
	run_rng = RunRNG.from_snapshot(run_state.run_rng_snapshot) if run_state.run_rng_snapshot != null and !run_state.run_rng_snapshot.is_empty() else RunRNG.new(run_seed)
	arcana_catalog = arcanum_catalog.duplicate()
	_start_run()
	_restore_saved_location()


func _generate_or_restore_map() -> void:
	var map_seed := int(run_state.map_seed) if run_state != null else 0
	if map_seed == 0:
		map_seed = RNGUtil.seed_from_label(run_seed, "map")
		if run_state != null:
			run_state.map_seed = map_seed
	var rng := RNG.new(map_seed)
	map.battle_pool = battle_pool
	map.generate_new_map(rng)
	_rehydrate_battle_assignments()
	if run_state != null and !run_state.cleared_room_coords.is_empty():
		map.restore_progress(run_state.cleared_room_coords)
	else:
		map.unlock_encounter_column(0)


func _derive_room_seed(room: Room, kind: String) -> int:
	if room == null:
		return 0
	return RNGUtil.seed_from_label(run_seed, "room:%d:%d:%s" % [room.row, room.column, kind])


func _derive_reward_seed(room: Room, kind: String) -> int:
	if room == null:
		return 0
	return RNGUtil.seed_from_label(run_seed, "room:%d:%d:%s_rewards" % [room.row, room.column, kind])


func _battle_assignment_room_key(room: Room) -> String:
	if room == null:
		return ""
	return "%d:%d" % [room.column, room.row]


func _resolve_battle_from_path(path: String) -> BattleData:
	if path.is_empty():
		return null
	return load(path) as BattleData


func _get_battle_pool() -> BattlePool:
	if battle_pool != null:
		return battle_pool
	if map != null:
		return map.battle_pool
	return null


func _get_battle_tier_for_room(room: Room) -> int:
	if room == null:
		return 0
	if int(room.type) == int(Room.RoomType.BOSS):
		return 3
	return 1 if int(room.column) > 2 else 0


func _apply_saved_battle_assignment(room: Room) -> bool:
	if run_state == null or room == null:
		return false
	var room_key := _battle_assignment_room_key(room)
	if room_key.is_empty() or !run_state.battle_assignments_by_room_key.has(room_key):
		return false
	var battle_path := str(run_state.battle_assignments_by_room_key.get(room_key, ""))
	room.battle_data = _resolve_battle_from_path(battle_path)
	if !battle_path.is_empty() and !run_state.consumed_battle_paths.has(battle_path):
		run_state.consumed_battle_paths.append(battle_path)
	return true


func _assign_battle_to_room_if_needed(room: Room) -> BattleData:
	if room == null:
		return null
	if _apply_saved_battle_assignment(room):
		return room.battle_data
	if run_state == null:
		room.battle_data = null
		return null

	var battle_data: BattleData = null
	var pool := _get_battle_pool()
	if pool != null:
		var tier := _get_battle_tier_for_room(room)
		var selection_seed := _derive_room_seed(room, "battle_assignment")
		var rng := RNG.new(selection_seed)
		battle_data = pool.get_random_battle_for_tier(rng, tier, run_state.consumed_battle_paths)

	var battle_path := ""
	if battle_data != null:
		battle_path = String(battle_data.resource_path)
		if !battle_path.is_empty() and !run_state.consumed_battle_paths.has(battle_path):
			run_state.consumed_battle_paths.append(battle_path)

	run_state.battle_assignments_by_room_key[_battle_assignment_room_key(room)] = battle_path
	room.battle_data = battle_data
	return battle_data


func _rehydrate_battle_assignments() -> void:
	if run_state == null or map == null or map.map_data == null:
		return
	for column_rooms: Array in map.map_data:
		for room_variant in column_rooms:
			var room := room_variant as Room
			if room == null:
				continue
			_apply_saved_battle_assignment(room)


func _card_proto_path(card_data: CardData) -> String:
	if card_data == null:
		return ""
	if !String(card_data.base_proto_path).is_empty():
		return String(card_data.base_proto_path)
	return String(card_data.resource_path)


func _resolve_card_from_path(path: String) -> CardData:
	if path.is_empty():
		return null
	return load(path) as CardData


func _resolve_card_paths(paths: PackedStringArray) -> Array[CardData]:
	var resolved: Array[CardData] = []
	for path in paths:
		var card := _resolve_card_from_path(String(path))
		if card != null:
			resolved.append(card)
	return resolved


func _resolve_arcanum_id(arcanum_id: String) -> Arcanum:
	if arcanum_id.is_empty() or arcanum_catalog == null:
		return null
	return arcanum_catalog.get_proto(StringName(arcanum_id))


func _resolve_arcanum_ids(ids: PackedStringArray) -> Array[Arcanum]:
	var resolved: Array[Arcanum] = []
	for arcanum_id in ids:
		var proto := _resolve_arcanum_id(String(arcanum_id))
		if proto != null:
			resolved.append(proto)
	return resolved


func _clear_pending_generated_state() -> void:
	if run_state == null:
		return
	run_state.pending_room_seed = 0
	run_state.pending_reward_seed = 0
	run_state.pending_treasure_arcanum_id = ""
	run_state.pending_shop_card_offer_paths = PackedStringArray()
	run_state.pending_shop_card_offer_costs = []
	run_state.pending_shop_claimed_card_offer_indices = []
	run_state.pending_shop_arcanum_offer_ids = PackedStringArray()
	run_state.pending_shop_arcanum_offer_costs = []
	run_state.pending_shop_claimed_arcanum_offer_indices = []
	run_state.pending_reward_gold_rewards = []
	run_state.pending_reward_card_choice_paths = PackedStringArray()
	run_state.pending_reward_soulbound_card_choice_paths = PackedStringArray()
	run_state.pending_reward_arcanum_ids = PackedStringArray()
	run_state.pending_reward_claimed_gold_indices = []
	run_state.pending_reward_card_claimed = false
	run_state.pending_reward_soulbound_card_claimed = false
	run_state.pending_reward_claimed_arcanum_indices = []


func _build_pending_shop_checkpoint(room: Room) -> void:
	if run_state == null or room == null:
		return
	if !run_state.pending_shop_card_offer_paths.is_empty() or !run_state.pending_shop_arcanum_offer_ids.is_empty():
		return
	run_state.pending_room_seed = _derive_room_seed(room, "shop")
	var rng := RNG.new(int(run_state.pending_room_seed))
	var ctx := ShopContext.new()
	ctx.run = self
	ctx.run_state = run_state
	ctx.player_data = player_data
	ctx.arcana_system = arcana_system
	ctx.arcana_catalog = arcana_catalog
	ctx.arcana_reward_pool = player_data.arcana_reward_pool if player_data != null else null

	var source_pile := run_state.draftable_cards if run_state != null and run_state.draftable_cards != null else (player_data.draftable_cards if player_data != null else null)
	var available_cards: Array[CardData] = []
	if source_pile != null:
		for card_data in source_pile.cards:
			available_cards.append(card_data)
	for _i in range(mini(3, available_cards.size())):
		var target_rarity := CardRarityManager.roll_rarity(
			rng,
			CardRarityManager.Source.SHOP,
			float(run_state.rare_pity_offset_percent),
			"shop_card_rarity_roll"
		)
		var card := CardRarityManager.select_card_for_rarity(
			rng,
			available_cards,
			target_rarity,
			"shop_card_offer"
		)
		if card == null:
			continue
		available_cards.erase(card)
		ctx.card_offers.append(card)
		ctx.card_offer_costs.append(rng.debug_range_i(100, 300, "shop_card_cost"))

	var eligible_arcana: Array[Arcanum] = []
	if arcana_catalog != null and ctx.arcana_reward_pool != null:
		for arcanum: Arcanum in arcana_catalog.arcana:
			if arcanum == null:
				continue
			if arcanum.starter_arcanum:
				continue
			if !ctx.arcana_reward_pool.allowed_ids.has(arcanum.get_id()):
				continue
			if arcana_system != null and arcana_system.has_arcanum(arcanum.get_id()):
				continue
			eligible_arcana.append(arcanum)
	for _i in range(mini(3, eligible_arcana.size())):
		var arcanum_index := rng.debug_range_i(0, eligible_arcana.size() - 1, "shop_arcanum_offer")
		var arcanum := eligible_arcana[arcanum_index]
		eligible_arcana.remove_at(arcanum_index)
		if arcanum == null:
			continue
		ctx.arcanum_offers.append(arcanum)
		ctx.arcanum_offer_costs.append(rng.debug_range_i(100, 300, "shop_arcanum_cost"))

	if arcana_system != null:
		arcana_system.on_shop_context_started(ctx)

	run_state.pending_shop_card_offer_paths = PackedStringArray()
	for card in ctx.card_offers:
		run_state.pending_shop_card_offer_paths.append(_card_proto_path(card))
	run_state.pending_shop_card_offer_costs = ctx.card_offer_costs.duplicate()
	run_state.pending_shop_claimed_card_offer_indices = []
	run_state.pending_shop_arcanum_offer_ids = PackedStringArray()
	for arcanum in ctx.arcanum_offers:
		run_state.pending_shop_arcanum_offer_ids.append(String(arcanum.get_id()))
	run_state.pending_shop_arcanum_offer_costs = ctx.arcanum_offer_costs.duplicate()
	run_state.pending_shop_claimed_arcanum_offer_indices = []


func _build_pending_shop_context() -> ShopContext:
	var ctx := ShopContext.new()
	ctx.run = self
	ctx.run_state = run_state
	ctx.player_data = player_data
	ctx.arcana_system = arcana_system
	ctx.arcana_catalog = arcana_catalog
	ctx.arcana_reward_pool = player_data.arcana_reward_pool if player_data != null else null
	ctx.card_offers = _resolve_card_paths(run_state.pending_shop_card_offer_paths)
	ctx.card_offer_costs = run_state.pending_shop_card_offer_costs.duplicate()
	ctx.claimed_card_offer_indices = run_state.pending_shop_claimed_card_offer_indices.duplicate()
	ctx.arcanum_offers = _resolve_arcanum_ids(run_state.pending_shop_arcanum_offer_ids)
	ctx.arcanum_offer_costs = run_state.pending_shop_arcanum_offer_costs.duplicate()
	ctx.claimed_arcanum_offer_indices = run_state.pending_shop_claimed_arcanum_offer_indices.duplicate()
	return ctx


func _build_pending_treasure_checkpoint(room: Room) -> void:
	if run_state == null or room == null:
		return
	if !run_state.pending_treasure_arcanum_id.is_empty():
		return
	run_state.pending_room_seed = _derive_room_seed(room, "treasure")
	var rng := RNG.new(int(run_state.pending_room_seed))
	var available_arcana: Array[Arcanum] = []
	if player_data != null and player_data.possible_arcana != null:
		for arcanum: Arcanum in player_data.possible_arcana.arcana:
			if arcanum == null:
				continue
			if arcana_system != null and arcana_system.has_arcanum(arcanum.get_id()):
				continue
			available_arcana.append(arcanum)
	if available_arcana.is_empty():
		return
	var selected_index := rng.debug_range_i(0, available_arcana.size() - 1, "treasure_arcanum")
	run_state.pending_treasure_arcanum_id = String(available_arcana[selected_index].get_id())


func _resolve_pending_treasure_arcanum() -> Arcanum:
	if run_state == null:
		return null
	return _resolve_arcanum_id(run_state.pending_treasure_arcanum_id)


func _build_reward_card_choices(rng: RNG, rarity_source: int, soulbound_only: bool) -> PackedStringArray:
	var chosen_paths := PackedStringArray()
	if run_state == null or rng == null:
		return chosen_paths
	var source_pile := run_state.draftable_cards if run_state.draftable_cards != null else (player_data.draftable_cards if player_data != null else null)
	if source_pile == null:
		return chosen_paths

	var possible_cards: Array[CardData] = []
	for card_data in source_pile.cards:
		if !_card_matches_reward_pool(card_data, soulbound_only):
			continue
		possible_cards.append(card_data)
	for _i in range(run_state.card_reward_choices):
		if possible_cards.is_empty():
			break
		var target_rarity := CardRarityManager.roll_rarity(
			rng,
			int(rarity_source),
			float(run_state.rare_pity_offset_percent),
			"reward_card_rarity_roll"
		)
		run_state.rare_pity_offset_percent = CardRarityManager.next_pity_offset(
			float(run_state.rare_pity_offset_percent),
			target_rarity
		)

		var selected_card := CardRarityManager.select_card_for_rarity(
			rng,
			possible_cards,
			target_rarity,
			"reward_card_pick"
		)
		if selected_card == null:
			continue
		possible_cards.erase(selected_card)
		chosen_paths.append(_card_proto_path(selected_card))
	return chosen_paths


func _card_matches_reward_pool(card_data: CardData, soulbound_only: bool) -> bool:
	if card_data == null:
		return false
	if soulbound_only:
		return card_data.is_soulbound_slot_card()
	return int(card_data.card_type) != int(CardData.CardType.SOULBOUND)


func _should_generate_soulbound_reward(rng: RNG, rarity_source: int) -> bool:
	if int(rarity_source) == int(CardRarityManager.Source.ELITE_COMBAT):
		return true
	if int(rarity_source) == int(CardRarityManager.Source.BOSS_REWARD):
		return true
	var chance := clampf(
		float(run_state.soulbound_pity_offset_percent),
		RunState.SOULBOUND_PITY_MIN_OFFSET,
		RunState.SOULBOUND_PITY_MAX_OFFSET
	)
	var roll := rng.debug_range_f(0.0, 100.0, "soulbound_reward_roll")
	return chance >= 100.0 or roll < chance


func _prepare_pending_reward_checkpoint(source_kind: int, room: Room) -> void:
	if run_state == null or room == null:
		return
	var reward_kind := "battle" if int(source_kind) == int(RewardContext.SourceKind.BATTLE) else "treasure"
	run_state.pending_reward_seed = _derive_reward_seed(room, reward_kind)
	run_state.pending_reward_gold_rewards = []
	run_state.pending_reward_card_choice_paths = PackedStringArray()
	run_state.pending_reward_soulbound_card_choice_paths = PackedStringArray()
	run_state.pending_reward_arcanum_ids = PackedStringArray()
	run_state.pending_reward_claimed_gold_indices = []
	run_state.pending_reward_card_claimed = false
	run_state.pending_reward_soulbound_card_claimed = false
	run_state.pending_reward_claimed_arcanum_indices = []

	var reward_ctx := RewardContext.new()
	reward_ctx.source_kind = source_kind
	reward_ctx.run_state = run_state
	reward_ctx.player_data = player_data
	reward_ctx.arcana_system = arcana_system
	reward_ctx.battle_data = room.battle_data if int(source_kind) == int(RewardContext.SourceKind.BATTLE) else null

	if reward_ctx.battle_data != null:
		var gold_rng := RNG.new(int(run_state.pending_reward_seed))
		reward_ctx.gold_rewards.append(int(reward_ctx.battle_data.roll_gold_reward_with_rng(gold_rng)))
		reward_ctx.include_card_reward = true
		var rarity_source := CardRarityManager.source_for_battle_tier(int(reward_ctx.battle_data.battle_tier))
		var card_rng := RNG.new(int(run_state.pending_reward_seed))
		reward_ctx.card_choices = _resolve_card_paths(_build_reward_card_choices(card_rng, rarity_source, false))
		if _should_generate_soulbound_reward(card_rng, rarity_source):
			reward_ctx.soulbound_card_choices = _resolve_card_paths(_build_reward_card_choices(card_rng, rarity_source, true))
			reward_ctx.include_soulbound_card_reward = !reward_ctx.soulbound_card_choices.is_empty()
			if int(rarity_source) == int(CardRarityManager.Source.NORMAL_COMBAT):
				if reward_ctx.include_soulbound_card_reward:
					run_state.reset_soulbound_pity()
				else:
					run_state.increase_soulbound_pity_after_miss()
		elif int(rarity_source) == int(CardRarityManager.Source.NORMAL_COMBAT):
			run_state.increase_soulbound_pity_after_miss()
	elif int(source_kind) == int(RewardContext.SourceKind.TREASURE):
		var treasure_arcanum := _resolve_pending_treasure_arcanum()
		if treasure_arcanum != null:
			reward_ctx.arcanum_rewards.append(treasure_arcanum)

	if arcana_system != null:
		arcana_system.on_reward_context_started(reward_ctx)

	run_state.pending_reward_gold_rewards = reward_ctx.gold_rewards.duplicate()
	run_state.pending_reward_card_choice_paths = PackedStringArray()
	for card in reward_ctx.card_choices:
		run_state.pending_reward_card_choice_paths.append(_card_proto_path(card))
	run_state.pending_reward_soulbound_card_choice_paths = PackedStringArray()
	for card in reward_ctx.soulbound_card_choices:
		run_state.pending_reward_soulbound_card_choice_paths.append(_card_proto_path(card))
	run_state.pending_reward_arcanum_ids = PackedStringArray()
	for arcanum in reward_ctx.arcanum_rewards:
		run_state.pending_reward_arcanum_ids.append(String(arcanum.get_id()))
	run_state.location_kind = RunState.LocationKind.ROOM_PENDING_BATTLE_REWARDS if int(source_kind) == int(RewardContext.SourceKind.BATTLE) else RunState.LocationKind.ROOM_PENDING_TREASURE_REWARDS


func _build_pending_reward_context() -> RewardContext:
	var reward_ctx := RewardContext.new()
	reward_ctx.source_kind = RewardContext.SourceKind.BATTLE if int(run_state.location_kind) == int(RunState.LocationKind.ROOM_PENDING_BATTLE_REWARDS) else RewardContext.SourceKind.TREASURE
	reward_ctx.run_state = run_state
	reward_ctx.player_data = player_data
	reward_ctx.arcana_system = arcana_system
	var room := map.get_room_at(int(run_state.pending_room_coord.x), int(run_state.pending_room_coord.y))
	reward_ctx.battle_data = room.battle_data if room != null and int(reward_ctx.source_kind) == int(RewardContext.SourceKind.BATTLE) else null
	reward_ctx.gold_rewards = run_state.pending_reward_gold_rewards.duplicate()
	reward_ctx.card_choices = _resolve_card_paths(run_state.pending_reward_card_choice_paths)
	reward_ctx.include_card_reward = !run_state.pending_reward_card_choice_paths.is_empty()
	reward_ctx.soulbound_card_choices = _resolve_card_paths(run_state.pending_reward_soulbound_card_choice_paths)
	reward_ctx.include_soulbound_card_reward = !run_state.pending_reward_soulbound_card_choice_paths.is_empty()
	reward_ctx.arcanum_rewards = _resolve_arcanum_ids(run_state.pending_reward_arcanum_ids)
	reward_ctx.claimed_gold_indices = run_state.pending_reward_claimed_gold_indices.duplicate()
	reward_ctx.card_reward_claimed = run_state.pending_reward_card_claimed
	reward_ctx.soulbound_card_reward_claimed = run_state.pending_reward_soulbound_card_claimed
	reward_ctx.claimed_arcanum_indices = run_state.pending_reward_claimed_arcanum_indices.duplicate()
	return reward_ctx


func _open_pending_reward_screen() -> void:
	var rewards_scn := _change_view(BATTLE_REWARDS_SCN) as BattleRewardsScreen
	rewards_scn.run_state = run_state
	rewards_scn.player_data = player_data
	rewards_scn.arcanum_system = arcana_system
	rewards_scn.arcana_system_container = arcana_system_container
	rewards_scn.run = self
	rewards_scn.populate_from_context(_build_pending_reward_context())


func _record_cleared_room(room: Room) -> void:
	if run_state == null or room == null:
		return
	var coord := Vector2i(int(room.column), int(room.row))
	if run_state.cleared_room_coords.has(coord):
		return
	run_state.cleared_room_coords.append(coord)


func _get_room_coord(room: Room) -> Vector2i:
	if room == null:
		return Vector2i(-1, -1)
	return Vector2i(int(room.column), int(room.row))


func _is_room_cleared(room: Room) -> bool:
	if run_state == null or room == null:
		return false
	return run_state.cleared_room_coords.has(_get_room_coord(room))


func _is_pending_room_resume(room: Room) -> bool:
	if run_state == null or room == null:
		return false
	if int(run_state.location_kind) == int(RunState.LocationKind.MAP):
		return false
	return run_state.pending_room_coord == _get_room_coord(room)


func _ensure_room_entry_allowed(room: Room, source: String) -> bool:
	if room == null:
		push_warning("Run.%s(): attempted to enter a null room." % source)
		_show_map()
		return false
	if _is_room_cleared(room) and !_is_pending_room_resume(room):
		push_warning("Run.%s(): rejected re-entry into cleared room at (%d,%d)." % [source, room.column, room.row])
		_show_map()
		return false
	return true


func _complete_pending_room_if_any() -> void:
	if run_state == null:
		return
	if int(run_state.location_kind) == int(RunState.LocationKind.MAP):
		return
	var pending := run_state.pending_room_coord
	if pending == Vector2i(-1, -1):
		return
	var room := map.get_room_at(int(pending.x), int(pending.y))
	if room == null:
		return
	map.set_active_room(room)
	_record_cleared_room(room)


func _on_pending_room_exited_to_map() -> void:
	_complete_pending_room_if_any()
	_show_map()


func _set_location_for_room(room: Room) -> void:
	if run_state == null or room == null:
		return
	run_state.pending_room_coord = Vector2i(int(room.column), int(room.row))
	match int(room.type):
		Room.RoomType.BATTLE, Room.RoomType.BOSS:
			run_state.location_kind = RunState.LocationKind.ROOM_PENDING_BATTLE
		Room.RoomType.TREASURE:
			run_state.location_kind = RunState.LocationKind.ROOM_PENDING_TREASURE
		Room.RoomType.REST:
			run_state.location_kind = RunState.LocationKind.ROOM_PENDING_REST
		Room.RoomType.SHOP:
			run_state.location_kind = RunState.LocationKind.ROOM_PENDING_SHOP
		_:
			run_state.location_kind = RunState.LocationKind.MAP


func _set_location_map() -> void:
	if run_state == null:
		return
	run_state.location_kind = RunState.LocationKind.MAP
	run_state.pending_room_coord = Vector2i(-1, -1)
	run_state.pending_battle_seed = 0
	_clear_pending_generated_state()


func _restore_saved_location() -> void:
	if run_state == null:
		return
	match int(run_state.location_kind):
		RunState.LocationKind.ROOM_PENDING_BATTLE, \
		RunState.LocationKind.ROOM_PENDING_TREASURE, \
		RunState.LocationKind.ROOM_PENDING_REST, \
		RunState.LocationKind.ROOM_PENDING_SHOP, \
		RunState.LocationKind.ROOM_PENDING_BATTLE_REWARDS, \
		RunState.LocationKind.ROOM_PENDING_TREASURE_REWARDS:
			var room := map.get_room_at(int(run_state.pending_room_coord.x), int(run_state.pending_room_coord.y))
			if room != null:
				map.set_active_room(room)
				if int(run_state.location_kind) == int(RunState.LocationKind.ROOM_PENDING_BATTLE):
					_on_battle_entered_with_seed(room, int(run_state.pending_battle_seed))
				elif int(run_state.location_kind) == int(RunState.LocationKind.ROOM_PENDING_TREASURE):
					_on_treasure_room_entered(room)
				elif int(run_state.location_kind) == int(RunState.LocationKind.ROOM_PENDING_REST):
					_on_rest_site_entered(room)
				elif int(run_state.location_kind) == int(RunState.LocationKind.ROOM_PENDING_SHOP):
					_on_shop_entered(room)
				elif int(run_state.location_kind) == int(RunState.LocationKind.ROOM_PENDING_BATTLE_REWARDS) or int(run_state.location_kind) == int(RunState.LocationKind.ROOM_PENDING_TREASURE_REWARDS):
					_open_pending_reward_screen()
				else:
					_show_map()
				return
	_show_map()


func _clear_run_arcana() -> void:
	for arcanum in arcana_system_container.get_all_arcana():
		if arcanum != null:
			arcana_system_container.remove_arcanum(arcanum.get_id())


func _sync_run_state_from_live_state() -> void:
	if run_state == null:
		return
	run_state.run_seed = run_seed
	if int(run_state.map_seed) == 0:
		run_state.map_seed = RNGUtil.seed_from_label(run_seed, "map")
	run_state.run_rng_snapshot = run_rng.snapshot() if run_rng != null else {}
	run_state.player_profile_id = String(player_data.profile_id) if player_data != null else ""
	if run_state.player_run_state == null:
		run_state.player_run_state = PlayerRunState.new()
	run_state.run_deck = run_deck
	run_state.draftable_cards = draftable_cards
	var owned_ids := PackedStringArray()
	for arcanum_id in arcana_system.get_my_arcana():
		owned_ids.append(String(arcanum_id))
	run_state.owned_arcanum_ids = owned_ids


func _persist_active_run() -> void:
	if run_state == null or _is_tutorial_mode():
		return
	_refresh_collection_display_pile()
	_sync_run_state_from_live_state()
	SaveService.save_active_run(run_state)


func _configure_run_deck() -> void:
	if run_deck == null:
		return
	var expected_signature_card := _pending_launch_signature_soul if _has_pending_launch_signature_payload else null
	run_deck.configure_soulbound_slot_count(soulbound_slot_count, _get_player_starter_soul(), expected_signature_card)
	_pending_launch_signature_soul = null
	_has_pending_launch_signature_payload = false


func _refresh_collection_display_pile() -> void:
	if collection_display_pile == null:
		collection_display_pile = CardPile.new()
	collection_display_pile.clear()
	if run_deck == null:
		return
	var display_pile := run_deck.build_collection_view_card_pile()
	for card_data in display_pile.cards:
		if card_data == null:
			continue
		collection_display_pile.add_back(card_data)


func _on_run_defeat() -> void:
	_force_close_pause_menu()
	if _is_tutorial_mode():
		return
	SaveService.clear_active_run()

func _is_tutorial_mode() -> bool:
	return startup_mode == int(RunProfile.StartMode.TUTORIAL)

func _exit_tutorial_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_packed(MAIN_MENU_SCN)

func _get_current_run_max_health() -> int:
	if run_state == null or run_state.player_run_state == null:
		return int(player_data.max_health) if player_data != null else 0
	return int(run_state.player_run_state.max_health)

func _get_current_run_health() -> int:
	if run_state == null or run_state.player_run_state == null:
		return _get_current_run_max_health()
	return int(run_state.player_run_state.current_health)

func _refresh_top_bar_health() -> void:
	if health_panel == null:
		return
	health_panel.update_health_view(_get_current_run_max_health(), _get_current_run_health())

func _ensure_player_run_state_initialized() -> void:
	if run_state == null:
		return
	if run_state.player_run_state == null:
		run_state.player_run_state = PlayerRunState.new()
	if player_data != null and int(run_state.player_run_state.max_health) <= 0:
		run_state.player_run_state.max_health = maxi(int(player_data.max_health), 0)
	if int(run_state.player_run_state.current_health) <= 0 and int(run_state.player_run_state.max_health) > 0:
		run_state.player_run_state.current_health = int(run_state.player_run_state.max_health)
	run_state.player_run_state.clamp_health()

func _apply_player_health_update(current_health: int, max_health: int) -> void:
	if run_state == null:
		return
	_ensure_player_run_state_initialized()
	if run_state.player_run_state == null:
		return
	run_state.player_run_state.max_health = maxi(int(max_health), 0)
	run_state.player_run_state.current_health = int(current_health)
	run_state.player_run_state.clamp_health()
	_refresh_top_bar_health()

func _on_player_battle_health_changed(current_health: int, max_health: int) -> void:
	_apply_player_health_update(current_health, max_health)

func _sync_player_health_from_active_battle() -> void:
	if run_state == null:
		return
	if current_view == null or current_view.get_child_count() == 0:
		return
	var battle := current_view.get_child(0) as Battle
	if battle == null:
		return
	_apply_player_health_update(
		int(battle.get_player_current_health()),
		int(battle.get_player_max_health())
	)
	
func _resolve_player_profile(profile_id: String) -> PlayerData:
	if player_catalog == null:
		return null
	var resolved := player_catalog.get_profile(profile_id)
	if resolved != null:
		return resolved
	return player_catalog.get_default_profile()

func _print_tree() -> void:
	print_tree_pretty()


func _on_menu_button_pressed() -> void:
	if pause_menu.visible:
		_close_pause_menu()
		return
	_open_pause_menu()


func _open_pause_menu() -> void:
	if pause_menu.visible:
		return
	_refresh_debug_ui()

	var battle := _get_active_battle()
	if battle != null:
		battle.pause_for_menu()

	get_tree().paused = true
	pause_menu.visible = true


func _close_pause_menu() -> void:
	_hide_debug_overlays()
	if !pause_menu.visible:
		get_tree().paused = false
		return
	var battle := _get_active_battle()
	if battle != null:
		battle.resume_from_menu()

	get_tree().paused = false
	pause_menu.visible = false


func _force_close_pause_menu() -> void:
	_hide_debug_overlays()
	var battle := _get_active_battle()
	if battle != null:
		battle.stop_playback()
	get_tree().paused = false
	pause_menu.visible = false


func _return_to_main_menu_from_pause() -> void:
	_force_close_pause_menu()
	get_tree().change_scene_to_packed(MAIN_MENU_SCN)


func _get_active_battle() -> Battle:
	if current_view == null or current_view.get_child_count() <= 0:
		return null
	return current_view.get_child(0) as Battle


func _ensure_debug_tools() -> void:
	run_save_picker = RUN_SAVE_PICKER_SCN.instantiate() as RunSavePicker
	save_name_dialog = SAVE_NAME_DIALOG_SCN.instantiate() as SaveNameDialog
	if run_save_picker != null:
		$UI.add_child(run_save_picker)
		run_save_picker.entry_selected.connect(_on_pause_debug_slot_selected)
	if save_name_dialog != null:
		$UI.add_child(save_name_dialog)
		save_name_dialog.save_requested.connect(_on_pause_debug_save_requested)


func _refresh_debug_ui() -> void:
	var enabled := Autoload.is_debug_mode_enabled()
	debug_ui.visible = enabled
	pause_debug_buttons.visible = enabled
	pause_debug_save_button.disabled = !enabled
	pause_debug_load_button.disabled = !enabled


func _hide_debug_overlays() -> void:
	if run_save_picker != null:
		run_save_picker.hide_picker()
	if save_name_dialog != null:
		save_name_dialog.hide_dialog()


func _on_pause_debug_save_pressed() -> void:
	if !Autoload.is_debug_mode_enabled() or run_state == null or save_name_dialog == null:
		return
	var existing_slot_keys := PackedStringArray()
	for info in SaveService.list_debug_run_saves():
		existing_slot_keys.append(info.slot_key)
	save_name_dialog.open(existing_slot_keys, "run_%d" % int(run_seed))


func _on_pause_debug_load_pressed() -> void:
	if !Autoload.is_debug_mode_enabled() or run_save_picker == null:
		return
	run_save_picker.show_slots("Load Debug Save", SaveService.list_debug_run_saves())


func _on_pause_debug_save_requested(slot_name: String) -> void:
	if run_state == null:
		return
	_sync_player_health_from_active_battle()
	_sync_run_state_from_live_state()
	SaveService.save_debug_run(run_state, slot_name)


func _on_pause_debug_slot_selected(slot_key: String) -> void:
	_force_close_pause_menu()
	Autoload.begin_load_debug_run(slot_key)
