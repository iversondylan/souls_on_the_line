# run.gd

class_name Run
extends Node

const BATTLE_SCN := preload("uid://k11cug4p8o3l")
const BATTLE_REWARDS_SCN := preload("uid://dg2swwanmuywt")
const CAMPFIRE_SCN := preload("uid://cc8jy5tcqxyuv")
#const MAP_SCENE := preload("uid://6p15tduy6cd2")
const SHOP_SCN := preload("uid://csf5mgsw4psnr")
const TREASURE_SCN := preload("uid://c4tto5c3yx2dt")



@export var run_startup: RunStartup = preload("uid://ck8qxvs3me11h")
@export var player_catalog: PlayerCatalog = preload("uid://b2ewfy12rhm0l")
@export var status_catalog: StatusCatalog
##Main menu startup will need to populate 
##this variable before changing scenes.
@export var arcanum_catalog: ArcanaCatalog

# TEMPORARY v
@export var extra_arcana: Array[Arcanum]
# TEMPORARY ^

@onready var map: Map = $Map

@onready var current_view: Node = $CurrentView
@onready var gold_display: GoldDisplay = %GoldDisplay
#@onready var arcana_system: ArcanaSystem = %ArcanaSystem
@onready var arcana_container: ArcanaContainer = %ArcanaContainer

@onready var collection_button: CardPileOpener = %CollectionButton
@onready var collection_pile_view: CardPileView = %CollectionPileView
@onready var arcanum_tooltip_popup: ArcanumTooltipPopup = %ArcanumTooltipPopup

@onready var map_button: Button = %MapButton
@onready var battle_button: Button = %BattleButton
@onready var shop_button: Button = %ShopButton
@onready var treasure_button: Button = %TreasureButton
@onready var rewards_button: Button = %RewardsButton
@onready var campfire_button: Button = %CampfireButton
@onready var health_panel: HealthBar = $TopBar/Items/HealthPanel

var run_state: RunState
var profile_data: ProfileData
var player_data: PlayerData
var run_seed: int = 0
var arcana_system: ArcanaSystem
var arcana_catalog: ArcanaCatalog
var draftable_cards: CardPile
var run_deck: RunDeck
var run_rng: RunRNG


func _ready() -> void:
	#print_tree_pretty()
	status_catalog.build_index()
	arcanum_catalog.build_index()
	if player_catalog != null:
		player_catalog.build_index()
	arcana_system = arcana_container.system
	
	if !run_startup:
		return
	profile_data = SaveService.load_or_create_profile()
	match run_startup.startup_type:
		RunStartup.StartupType.NEW_RUN:
			_start_new_run()
		RunStartup.StartupType.CONTINUED_RUN:
			_continue_saved_run()

func _start_run() -> void:
	if run_state == null:
		run_state = RunState.new()
	run_state.draftable_cards = draftable_cards
	if run_state.run_deck == null:
		if run_deck == null:
			run_deck = RunDeck.new()
		if run_deck.card_collection == null and player_data != null and player_data.starting_deck != null:
			run_deck.card_collection = player_data.starting_deck.duplicate()
		run_state.run_deck = run_deck
	else:
		run_deck = run_state.run_deck
	
	##This is for messing around with extra starting gold
	if run_startup != null and int(run_startup.startup_type) == int(RunStartup.StartupType.NEW_RUN):
		run_state.gold += player_data.bonus_starting_gold
	_ensure_player_run_state_initialized()
	
	_connect_signals()
	_init_top_bar()
	_generate_or_restore_map()
	#map.generate_new_map()
	#map.unlock_encounter_column(0)
	_persist_active_run()

func _change_view(scene: PackedScene) -> Node:
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	get_tree().paused = false
	var new_view := scene.instantiate()
	current_view.add_child(new_view)
	map.hide_map()
	
	return new_view



func _show_map() -> void:
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
				arcana_container.add_arcanum(proto)
	elif player_data != null and player_data.starting_arcanum != null:
		arcana_container.add_arcanum(player_data.starting_arcanum)
	
# TEMPORARY v
	if run_state != null and run_state.owned_arcanum_ids.is_empty():
		for arcanum: Arcanum in extra_arcana:
			arcana_container.add_arcana([arcanum])
# TEMPORARY ^

	
	collection_button.card_pile = run_deck.card_collection
	collection_pile_view.card_pile = run_deck.card_collection
	collection_pile_view.player_data = player_data
	collection_button.pressed.connect(collection_pile_view.show_current_view.bind("Collection"))

func _on_battle_entered(room: Room) -> void:
	_on_battle_entered_with_seed(room, -1)


func _on_battle_entered_with_seed(room: Room, existing_battle_seed: int = -1) -> void:
	var label := "room:%d:%d:battle_seed" % [room.row, room.column]
	var battle_seed := int(existing_battle_seed)
	if battle_seed < 0:
		var rng := run_rng.get_stream(label)
		# simplest: battle_seed is first randi from this room stream
		battle_seed = int(rng.randi())
		run_rng.commit(rng)
	print("[Run] battle_seed for (%d,%d) = %d" % [room.row, room.column, battle_seed])
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
	#battle_scn.arcana = arcana_container.system
	battle_scn.my_arcana = arcana_system.get_my_arcana()
	battle_scn.start_battle()

func _on_rest_site_entered(room: Room = map.last_room) -> void:
	map.set_active_room(room)
	_set_location_for_room(room)
	if int(run_state.pending_room_seed) == 0:
		run_state.pending_room_seed = _derive_room_seed(room, "rest")
	_persist_active_run()
	var campfire := _change_view(CAMPFIRE_SCN) as Campfire
	campfire.run_state = run_state

func _on_shop_entered(room: Room = map.last_room) -> void:
	map.set_active_room(room)
	_set_location_for_room(room)
	_build_pending_shop_checkpoint(room)
	_persist_active_run()
	var shop := _change_view(SHOP_SCN) as Shop
	shop.run = self
	shop.player_data = player_data
	shop.run_state = run_state
	shop.arcana_system = arcana_container.system
	shop.arcana_catalog = arcana_catalog
	shop.arcana_reward_pool = player_data.arcana_reward_pool
	var shop_ctx := _build_pending_shop_context()
	shop.populate_from_context(shop_ctx)

func _on_battle_won() -> void:
	_sync_player_health_from_active_battle()
	_prepare_pending_reward_checkpoint(int(RewardContext.SourceKind.BATTLE), map.last_room)
	_persist_active_run()
	_open_pending_reward_screen()

func _on_treasure_room_entered(room: Room = map.last_room) -> void:
	map.set_active_room(room)
	_set_location_for_room(room)
	_build_pending_treasure_checkpoint(room)
	_persist_active_run()
	var treasure_scn := _change_view(TREASURE_SCN) as TreasureRoom
	treasure_scn.arcanum_system = arcana_container.system
	treasure_scn.player_data = player_data
	treasure_scn.set_found_arcanum(_resolve_pending_treasure_arcanum())

func _on_treasure_room_exited(arcanum: Arcanum) -> void:
	if arcanum != null and run_state != null and run_state.pending_treasure_arcanum_id.is_empty():
		run_state.pending_treasure_arcanum_id = String(arcanum.get_id())
	_prepare_pending_reward_checkpoint(int(RewardContext.SourceKind.TREASURE), map.last_room)
	_persist_active_run()
	_open_pending_reward_screen()

func _on_map_exited(room: Room) -> void:
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


func _start_new_run() -> void:
	run_seed = run_startup.run_seed
	if run_seed == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		run_seed = int(rng.randi())
		run_startup.run_seed = run_seed
	print("run.gd new run startup seed: ", run_seed)
	run_rng = RunRNG.new(run_seed)

	player_data = _resolve_player_profile(run_startup.player_profile_id)
	if player_data == null:
		push_warning("Run._start_new_run(): no player profile found for id '%s'" % run_startup.player_profile_id)
		return

	var starting_deck := player_data.starting_deck.duplicate()
	draftable_cards = player_data.draftable_cards.duplicate()

	var soul_snapshot: CardSnapshot = null
	if profile_data != null and profile_data.soul_recess_state != null:
		if run_startup != null and !run_startup.selected_starting_soul_uid.is_empty():
			soul_snapshot = profile_data.soul_recess_state.get_attuned_soul_snapshot(run_startup.selected_starting_soul_uid)
		if soul_snapshot == null:
			soul_snapshot = profile_data.soul_recess_state.get_selected_starting_soul_snapshot()
	if soul_snapshot != null:
		var carried_card := soul_snapshot.instantiate_card()
		if carried_card != null:
			starting_deck.add_back(carried_card)

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
	run_deck.card_collection = starting_deck
	run_state.run_deck = run_deck
	for arcanum in extra_arcana:
		if arcanum != null:
			run_state.owned_arcanum_ids.append(String(arcanum.get_id()))
	print("run.gd STARTING RUN WITH NEW CHARACTER")
	SaveService.save_profile(profile_data)
	_start_run()


func _continue_saved_run() -> void:
	run_state = SaveService.load_active_run()
	if run_state == null:
		push_warning("Run._continue_saved_run(): no active run save found")
		return

	player_data = _resolve_player_profile(run_state.player_profile_id)
	if player_data == null:
		push_warning("Run._continue_saved_run(): unknown player_profile_id '%s'" % run_state.player_profile_id)
		return
	if run_state.player_profile_id.is_empty():
		run_state.player_profile_id = String(player_data.profile_id)
	_ensure_player_run_state_initialized()

	draftable_cards = run_state.draftable_cards if run_state.draftable_cards != null else player_data.draftable_cards.duplicate()
	run_deck = run_state.run_deck if run_state.run_deck != null else RunDeck.new()
	if run_deck.card_collection == null:
		run_deck.card_collection = player_data.starting_deck.duplicate()
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
	map.generate_new_map(rng)
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
	run_state.pending_reward_arcanum_ids = PackedStringArray()
	run_state.pending_reward_claimed_gold_indices = []
	run_state.pending_reward_card_claimed = false
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
		var card_index := rng.debug_range_i(0, available_cards.size() - 1, "shop_card_offer")
		var card := available_cards[card_index]
		available_cards.remove_at(card_index)
		if card == null:
			continue
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


func _build_reward_card_choices(seed: int) -> PackedStringArray:
	var chosen_paths := PackedStringArray()
	if run_state == null:
		return chosen_paths
	var source_pile := run_state.draftable_cards if run_state.draftable_cards != null else (player_data.draftable_cards if player_data != null else null)
	if source_pile == null:
		return chosen_paths

	var rng := RNG.new(seed)
	var possible_cards: Array[CardData] = []
	for card_data in source_pile.cards:
		possible_cards.append(card_data)
	for _i in range(run_state.card_reward_choices):
		if possible_cards.is_empty():
			break
		var total_weight := run_state.common_weight + run_state.uncommon_weight + run_state.rare_weight
		var roll := rng.debug_range_f(0.0, total_weight, "reward_card_roll")
		var target_rarity := CardData.Rarity.RARE
		if roll <= run_state.common_weight:
			target_rarity = CardData.Rarity.COMMON
		elif roll <= run_state.common_weight + run_state.uncommon_weight:
			target_rarity = CardData.Rarity.UNCOMMON
		if target_rarity == CardData.Rarity.RARE:
			run_state.rare_weight = RunState.BASE_RARE_WEIGHT
		else:
			run_state.rare_weight = clampf(run_state.rare_weight + 0.3, RunState.BASE_RARE_WEIGHT, 5.0)

		var matching_indices: Array[int] = []
		for idx in range(possible_cards.size()):
			var candidate: CardData = possible_cards[idx]
			if candidate != null and candidate.rarity == target_rarity:
				matching_indices.append(idx)
		if matching_indices.is_empty():
			for idx in range(possible_cards.size()):
				matching_indices.append(idx)
		var selected_slot := matching_indices[rng.debug_range_i(0, matching_indices.size() - 1, "reward_card_pick")]
		var selected_card := possible_cards[selected_slot]
		possible_cards.remove_at(selected_slot)
		if selected_card == null:
			continue
		chosen_paths.append(_card_proto_path(selected_card))
	return chosen_paths


func _prepare_pending_reward_checkpoint(source_kind: int, room: Room) -> void:
	if run_state == null or room == null:
		return
	var reward_kind := "battle" if int(source_kind) == int(RewardContext.SourceKind.BATTLE) else "treasure"
	run_state.pending_reward_seed = _derive_reward_seed(room, reward_kind)
	run_state.pending_reward_gold_rewards = []
	run_state.pending_reward_card_choice_paths = PackedStringArray()
	run_state.pending_reward_arcanum_ids = PackedStringArray()
	run_state.pending_reward_claimed_gold_indices = []
	run_state.pending_reward_card_claimed = false
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
		reward_ctx.card_choices = _resolve_card_paths(_build_reward_card_choices(int(run_state.pending_reward_seed)))
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
	reward_ctx.arcanum_rewards = _resolve_arcanum_ids(run_state.pending_reward_arcanum_ids)
	reward_ctx.claimed_gold_indices = run_state.pending_reward_claimed_gold_indices.duplicate()
	reward_ctx.card_reward_claimed = run_state.pending_reward_card_claimed
	reward_ctx.claimed_arcanum_indices = run_state.pending_reward_claimed_arcanum_indices.duplicate()
	return reward_ctx


func _open_pending_reward_screen() -> void:
	var rewards_scn := _change_view(BATTLE_REWARDS_SCN) as BattleRewardsScreen
	rewards_scn.run_state = run_state
	rewards_scn.player_data = player_data
	rewards_scn.arcanum_system = arcana_system
	rewards_scn.run = self
	rewards_scn.populate_from_context(_build_pending_reward_context())


func _record_cleared_room(room: Room) -> void:
	if run_state == null or room == null:
		return
	var coord := Vector2i(int(room.column), int(room.row))
	if run_state.cleared_room_coords.has(coord):
		return
	run_state.cleared_room_coords.append(coord)


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
	for arcanum in arcana_container.get_all_arcana():
		if arcanum != null:
			arcana_container.remove_arcanum(arcanum.get_id())


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
	if run_state == null:
		return
	_sync_run_state_from_live_state()
	SaveService.save_active_run(run_state)


func _on_run_defeat() -> void:
	SaveService.clear_active_run()

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

func _sync_player_health_from_active_battle() -> void:
	if run_state == null or run_state.player_run_state == null:
		return
	if current_view == null or current_view.get_child_count() == 0:
		return
	var battle := current_view.get_child(0) as Battle
	if battle == null:
		return
	run_state.player_run_state.current_health = int(battle.get_player_current_health())
	run_state.player_run_state.max_health = int(battle.get_player_max_health())
	_refresh_top_bar_health()
	
func _resolve_player_profile(profile_id: String) -> PlayerData:
	if player_catalog == null:
		return null
	var resolved := player_catalog.get_profile(profile_id)
	if resolved != null:
		return resolved
	return player_catalog.get_default_profile()

#func make_rng(label: String) -> RandomNumberGenerator:
	#var rng := RandomNumberGenerator.new()
	#rng.seed = RNGUtil.seed_from_strings(run_seed, label)
	#return rng

#static func rc_hash(row: int, col: int) -> int:
	#return ("%d,%d" % [row, col]).hash()

func _print_tree() -> void:
	print_tree_pretty()
