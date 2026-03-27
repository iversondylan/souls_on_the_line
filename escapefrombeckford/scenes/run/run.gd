# run.gd

class_name Run
extends Node

const BATTLE_SCN := preload("res://scenes/battle.tscn")
const BATTLE_REWARDS_SCN := preload("res://scenes/battle_rewards/battle_rewards.tscn")
const CAMPFIRE_SCN := preload("res://scenes/campfire/campfire.tscn")
#const MAP_SCENE := preload("res://scenes/map/map.tscn")
const SHOP_SCN := preload("res://scenes/shop/shop.tscn")
const TREASURE_SCN := preload("res://scenes/treasure/treasure_room.tscn")



@export var run_startup: RunStartup = preload("res://scenes/run/run_startup.tres")
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

var account: RunAccount
var profile_data: ProfileData
var player_definition: PlayerData
var player_data: PlayerData
var run_seed: int = 0
var arcana_system: ArcanaSystem
var arcana_catalog: ArcanaCatalog
var starting_deck: CardPile
var draftable_cards: CardPile
var run_deck: RunDeck
var run_rng: RunRNG


func _ready() -> void:
	#print_tree_pretty()
	status_catalog.build_index()
	arcanum_catalog.build_index()
	arcana_system = arcana_container.system
	arcana_system.modifier_tokens_changed.connect(_on_modifier_tokens_changed)
	
	if !run_startup:
		return
	profile_data = SaveService.load_or_create_profile()
	match run_startup.startup_type:
		RunStartup.StartupType.NEW_RUN:
			_start_new_run()
		RunStartup.StartupType.CONTINUED_RUN:
			_continue_saved_run()

func _start_run() -> void:
	if account == null:
		account = RunAccount.new()
	account.draftable_cards = draftable_cards
	if account.run_deck == null:
		run_deck = RunDeck.new()
		run_deck.card_collection = starting_deck
		account.run_deck = run_deck
	else:
		run_deck = account.run_deck
	
	##This is for messing around with extra starting gold
	if run_startup != null and int(run_startup.startup_type) == int(RunStartup.StartupType.NEW_RUN):
		account.gold += player_definition.bonus_starting_gold
	
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
	_persist_active_run()

func _connect_signals() -> void:
	Events.battle_won.connect(_on_battle_won)
	Events.battle_rewards_exited.connect(_show_map)
	Events.campfire_exited.connect(_show_map)
	Events.map_exited.connect(_on_map_exited)
	Events.shop_exited.connect(_show_map)
	Events.treasure_room_exited.connect(_on_treasure_room_exited)
	Events.request_defeat.connect(_on_run_defeat)
	
	battle_button.pressed.connect(_change_view.bind(BATTLE_SCN))
	campfire_button.pressed.connect(_change_view.bind(CAMPFIRE_SCN))
	map_button.pressed.connect(_show_map)
	rewards_button.pressed.connect(_change_view.bind(BATTLE_REWARDS_SCN))
	shop_button.pressed.connect(_on_shop_entered)
	treasure_button.pressed.connect(_on_treasure_room_entered)

func _init_top_bar() -> void:
	player_data.combatant_data_changed.connect(health_panel.update_health.bind(player_data))
	health_panel.update_health(player_data)
	gold_display.run_account = account
	
	_clear_run_arcana()
	if account != null and !account.owned_arcanum_ids.is_empty():
		for arcanum_id in account.owned_arcanum_ids:
			var proto := arcanum_catalog.get_proto(StringName(arcanum_id))
			if proto != null:
				arcana_container.add_arcanum(proto)
	elif player_definition != null and player_definition.starting_arcanum != null:
		arcana_container.add_arcanum(player_definition.starting_arcanum)
	
# TEMPORARY v
	if account != null and account.owned_arcanum_ids.is_empty():
		for arcanum: Arcanum in extra_arcana:
			arcana_container.add_arcana([arcanum])
# TEMPORARY ^

	
	collection_button.card_pile = run_deck.card_collection
	collection_pile_view.card_pile = run_deck.card_collection
	collection_pile_view.player_data = player_data
	collection_button.pressed.connect(collection_pile_view.show_current_view.bind("Collection"))

func _on_battle_entered(room: Room) -> void:
	#var battle_seed := RNGUtil.mix_seed(run_seed, rc_hash(room.row, room.column))
	#battle_scn.run_seed = run_seed
	#battle_scn.battle_seed = battle_seed
	var label := "room:%d:%d:battle_seed" % [room.row, room.column]
	var rng := run_rng.get_stream(label)
	
	# simplest: battle_seed is first randi from this room stream
	var battle_seed := int(rng.randi())
	run_rng.commit(rng)
	print("[Run] battle_seed for (%d,%d) = %d" % [room.row, room.column, battle_seed])
	_set_location_for_room(room)
	_persist_active_run()
	var battle_scn: Battle = _change_view(BATTLE_SCN) as Battle
	battle_scn.run_seed = run_seed
	battle_scn.battle_seed = battle_seed
	battle_scn.run = self
	battle_scn.player_data = player_data
	battle_scn.run_deck = run_deck
	battle_scn.battle_data = room.battle_data
	#battle_scn.arcana = arcana_container.system
	battle_scn.my_arcana = arcana_system.get_my_arcana()
	battle_scn.start_battle()

func _on_rest_site_entered() -> void:
	_set_location_for_room(map.last_room)
	_persist_active_run()
	var campfire := _change_view(CAMPFIRE_SCN) as Campfire
	campfire.player_data = player_data

func _on_shop_entered() -> void:
	#print("run.gd _on_shop_entered()")
	_set_location_for_room(map.last_room)
	_persist_active_run()
	var shop := _change_view(SHOP_SCN) as Shop
	shop.run = self
	shop.player_data = player_data
	shop.run_account = account
	shop.arcana_system = arcana_container.system
	shop.arcana_catalog = arcana_catalog
	shop.arcana_reward_pool = player_data.arcana_reward_pool
	Events.request_shop_modifiers.emit(shop)
	var shop_ctx := shop.build_opening_context()
	if arcana_system != null:
		arcana_system.on_shop_context_started(shop_ctx)
	shop.populate_from_context(shop_ctx)

func _on_battle_won() -> void:
	var rewards_scn := _change_view(BATTLE_REWARDS_SCN) as BattleRewardsScreen
	rewards_scn.run_account = account
	rewards_scn.player_data = player_data
	rewards_scn.arcanum_system = arcana_system
	rewards_scn.run = self

	var reward_ctx := RewardContext.new()
	reward_ctx.source_kind = int(RewardContext.SourceKind.BATTLE)
	reward_ctx.run_account = account
	reward_ctx.player_data = player_data
	reward_ctx.arcana_system = arcana_system
	reward_ctx.battle_data = map.last_room.battle_data if map != null and map.last_room != null else null
	if reward_ctx.battle_data != null:
		reward_ctx.gold_rewards.append(int(reward_ctx.battle_data.roll_gold_reward()))
	reward_ctx.include_card_reward = true
	if arcana_system != null:
		arcana_system.on_reward_context_started(reward_ctx)
	rewards_scn.populate_from_context(reward_ctx)

func _on_treasure_room_entered() -> void:
	_set_location_for_room(map.last_room)
	_persist_active_run()
	var treasure_scn := _change_view(TREASURE_SCN) as TreasureRoom
	treasure_scn.arcanum_system = arcana_container.system
	treasure_scn.player_data = player_data
	treasure_scn.generate_arcanum()

func _on_treasure_room_exited(arcanum: Arcanum) -> void:
	var reward_scn := _change_view(BATTLE_REWARDS_SCN) as BattleRewardsScreen
	reward_scn.run_account = account
	reward_scn.player_data = player_data
	reward_scn.arcanum_system = arcana_container.system
	reward_scn.run = self

	var reward_ctx := RewardContext.new()
	reward_ctx.source_kind = int(RewardContext.SourceKind.TREASURE)
	reward_ctx.run_account = account
	reward_ctx.player_data = player_data
	reward_ctx.arcana_system = arcana_system
	if arcanum != null:
		reward_ctx.arcanum_rewards.append(arcanum)
	if arcana_system != null:
		arcana_system.on_reward_context_started(reward_ctx)
	reward_scn.populate_from_context(reward_ctx)

func _on_map_exited(room: Room) -> void:
	_record_cleared_room(room)
	match room.type:
		Room.RoomType.BATTLE:
			_on_battle_entered(room)
		Room.RoomType.TREASURE:
			_on_treasure_room_entered()
		Room.RoomType.REST:
			_on_rest_site_entered()
		Room.RoomType.SHOP:
			_on_shop_entered()
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

	player_definition = run_startup.player_data
	player_data = player_definition.create_instance()
	player_data.set_health(player_data.max_health)

	if run_startup.starting_deck != null:
		starting_deck = run_startup.starting_deck.duplicate()
	else:
		starting_deck = player_definition.starting_deck.duplicate()
	if run_startup.draftable_cards != null:
		draftable_cards = run_startup.draftable_cards.duplicate()
	else:
		draftable_cards = player_definition.draftable_cards.duplicate()

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

	arcana_catalog = run_startup.arcana_catalog.duplicate() if run_startup.arcana_catalog != null else arcanum_catalog.duplicate()
	account = RunAccount.new()
	account.run_seed = run_seed
	account.player_definition = player_definition
	account.player_run_state = PlayerRunState.new()
	account.player_run_state.current_health = player_definition.max_health
	account.owned_arcanum_ids = PackedStringArray([String(player_definition.starting_arcanum.get_id())]) if player_definition.starting_arcanum != null else PackedStringArray()
	for arcanum in extra_arcana:
		if arcanum != null:
			account.owned_arcanum_ids.append(String(arcanum.get_id()))
	print("run.gd STARTING RUN WITH NEW CHARACTER")
	SaveService.save_profile(profile_data)
	_start_run()


func _continue_saved_run() -> void:
	account = SaveService.load_active_run()
	if account == null:
		push_warning("Run._continue_saved_run(): no active run save found")
		return

	if account.player_definition == null:
		push_warning("Run._continue_saved_run(): saved run missing player_definition")
		return

	player_definition = account.player_definition
	player_data = player_definition.create_instance()
	if account.player_run_state != null:
		player_data.set_health(account.player_run_state.current_health)
	else:
		player_data.set_health(player_definition.max_health)

	draftable_cards = account.draftable_cards if account.draftable_cards != null else player_definition.draftable_cards.duplicate()
	run_deck = account.run_deck if account.run_deck != null else RunDeck.new()
	if run_deck.card_collection == null:
		run_deck.card_collection = player_definition.starting_deck.duplicate()
	run_seed = int(account.run_seed)
	run_rng = RunRNG.new(run_seed)
	arcana_catalog = run_startup.arcana_catalog.duplicate() if run_startup.arcana_catalog != null else arcanum_catalog.duplicate()
	_start_run()
	_restore_saved_location()


func _generate_or_restore_map() -> void:
	var rng := run_rng.get_stream("map")
	map.generate_new_map(rng)
	run_rng.commit(rng)
	if account != null and !account.cleared_room_coords.is_empty():
		map.restore_progress(account.cleared_room_coords)
	else:
		map.unlock_encounter_column(0)


func _record_cleared_room(room: Room) -> void:
	if account == null or room == null:
		return
	var coord := Vector2i(int(room.column), int(room.row))
	if account.cleared_room_coords.has(coord):
		return
	account.cleared_room_coords.append(coord)


func _set_location_for_room(room: Room) -> void:
	if account == null or room == null:
		return
	account.pending_room_coord = Vector2i(int(room.column), int(room.row))
	match int(room.type):
		Room.RoomType.BATTLE, Room.RoomType.BOSS:
			account.location_kind = RunAccount.LocationKind.ROOM_PENDING_BATTLE
		Room.RoomType.TREASURE:
			account.location_kind = RunAccount.LocationKind.ROOM_PENDING_TREASURE
		Room.RoomType.REST:
			account.location_kind = RunAccount.LocationKind.ROOM_PENDING_REST
		Room.RoomType.SHOP:
			account.location_kind = RunAccount.LocationKind.ROOM_PENDING_SHOP
		_:
			account.location_kind = RunAccount.LocationKind.MAP


func _set_location_map() -> void:
	if account == null:
		return
	account.location_kind = RunAccount.LocationKind.MAP
	account.pending_room_coord = Vector2i(-1, -1)


func _restore_saved_location() -> void:
	if account == null:
		return
	match int(account.location_kind):
		RunAccount.LocationKind.ROOM_PENDING_BATTLE, \
		RunAccount.LocationKind.ROOM_PENDING_TREASURE, \
		RunAccount.LocationKind.ROOM_PENDING_REST, \
		RunAccount.LocationKind.ROOM_PENDING_SHOP:
			var room := map.get_room_at(int(account.pending_room_coord.x), int(account.pending_room_coord.y))
			if room != null:
				_on_map_exited(room)
				return
	_show_map()


func _clear_run_arcana() -> void:
	for arcanum in arcana_container.get_all_arcana():
		if arcanum != null:
			arcana_container.remove_arcanum(arcanum.get_id())


func _sync_account_from_live_state() -> void:
	if account == null:
		return
	account.run_seed = run_seed
	account.player_definition = player_definition
	if account.player_run_state == null:
		account.player_run_state = PlayerRunState.new()
	if player_data != null:
		account.player_run_state.current_health = int(player_data.health)
	account.run_deck = run_deck
	account.draftable_cards = draftable_cards
	var owned_ids := PackedStringArray()
	for arcanum_id in arcana_system.get_my_arcana():
		owned_ids.append(String(arcanum_id))
	account.owned_arcanum_ids = owned_ids


func _persist_active_run() -> void:
	if account == null:
		return
	_sync_account_from_live_state()
	SaveService.save_active_run(account)


func _on_run_defeat() -> void:
	SaveService.clear_active_run()
	
#func get_modifier_tokens_for(target: Node) -> Array[ModifierToken]:
	##print("run.gd get_modifier_tokens()")
	#var tokens: Array[ModifierToken] = []
	#
	## 1. Arcana (global, persistent)
	#tokens.append_array(arcana_container.get_modifier_tokens_for(target))
	## (or arcana_system.get_modifier_tokens_for, both work)
#
	#
	## 2. Combat-only tokens (if in battle)
	##var battle_scene := _get_active_battle_scene()
	##if battle_scene and target is Fighter:
		##tokens.append_array(battle_scene.get_modifier_tokens_for(target))
	#
	#return tokens

#func _get_active_battle_scene() -> BattleScene:
	#var view: Node = current_view.get_child(0)
	#if view is Battle:
		#return view.battle_scene
	#return null
	
func _on_modifier_tokens_changed(mod_type: Modifier.Type) -> void:
	if current_view.get_child_count() == 0:
		return
	
	var view := current_view.get_child(0)
	
	if view.has_method("on_modifier_tokens_changed"):
		view.on_modifier_tokens_changed(mod_type)

#func make_rng(label: String) -> RandomNumberGenerator:
	#var rng := RandomNumberGenerator.new()
	#rng.seed = RNGUtil.seed_from_strings(run_seed, label)
	#return rng

#static func rc_hash(row: int, col: int) -> int:
	#return ("%d,%d" % [row, col]).hash()

func _print_tree() -> void:
	print_tree_pretty()
