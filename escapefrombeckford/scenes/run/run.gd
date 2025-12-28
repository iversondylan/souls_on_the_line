class_name Run
extends Node

const BATTLE_SCN := preload("res://scenes/battle.tscn")
const BATTLE_REWARDS_SCN := preload("res://scenes/battle_rewards/battle_rewards.tscn")
const CAMPFIRE_SCN := preload("res://scenes/campfire/campfire.tscn")
#const MAP_SCENE := preload("res://scenes/map/map.tscn")
const SHOP_SCN := preload("res://scenes/shop/shop.tscn")
const TREASURE_SCN := preload("res://scenes/treasure/treasure_room.tscn")



@export var run_startup: RunStartup

##Main menu startup will need to populate 
##this variable before changing scenes.
#@export var arcana_catalog: Arcana

@onready var map: Map = $Map

@onready var current_view: Node = $CurrentView
@onready var gold_display: GoldDisplay = %GoldDisplay
@onready var arcana_system: ArcanaSystem = %ArcanaSystem

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
var player_data: PlayerData
var arcana_catalog: Arcana
var starting_deck: CardPile
var draftable_cards: CardPile
var deck: Deck

func _ready() -> void:
	arcana_system.modifier_tokens_changed.connect(_on_modifier_tokens_changed)
	if !run_startup:
		return
	match run_startup.startup_type:
		RunStartup.StartupType.NEW_RUN:
			player_data = run_startup.player_data.create_instance()
			player_data.set_health(player_data.max_health)
			starting_deck = run_startup.player_data.starting_deck.duplicate()
			draftable_cards = run_startup.player_data.draftable_cards.duplicate()
			#arcana_reward_pool = run_startup.player_data.arcana_reward_pool.duplicate()
			arcana_catalog = run_startup.arcana_catalog.duplicate()
			print("run.gd STARTING RUN WITH NEW CHARACTER")
			_start_run()
		RunStartup.StartupType.CONTINUED_RUN:
			print("TO DO: load previous run")

func _start_run() -> void:
	account = RunAccount.new()
	account.draftable_cards = draftable_cards
	deck = Deck.new()
	deck.card_collection = starting_deck
	account.deck = deck
	
	##This is for messing around with extra starting gold
	account.gold += player_data.bonus_starting_gold
	
	_connect_signals()
	_init_top_bar()
	map.generate_new_map()
	map.unlock_encounter_column(0)

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
	map.unlock_next_rooms()

func _connect_signals() -> void:
	Events.battle_won.connect(_on_battle_won)
	Events.battle_rewards_exited.connect(_show_map)
	Events.campfire_exited.connect(_show_map)
	Events.map_exited.connect(_on_map_exited)
	Events.shop_exited.connect(_show_map)
	Events.treasure_room_exited.connect(_on_treasure_room_exited)
	
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
	
	arcana_system.add_arcanum(player_data.starting_arcanum)
	
	collection_button.card_pile = deck.card_collection
	collection_pile_view.card_pile = deck.card_collection
	collection_pile_view.deck = deck
	collection_pile_view.player_data = player_data
	collection_button.pressed.connect(collection_pile_view.show_current_collection_view.bind("Collection"))

func _on_battle_entered(room: Room) -> void:
	var battle_scn: Battle = _change_view(BATTLE_SCN) as Battle
	battle_scn.run = self
	battle_scn.player_data = player_data
	battle_scn.deck = deck
	battle_scn.battle_data = room.battle_data
	battle_scn.arcana = arcana_system
	battle_scn.start_battle()

func _on_rest_site_entered() -> void:
	var campfire := _change_view(CAMPFIRE_SCN) as Campfire
	campfire.player_data = player_data

func _on_shop_entered() -> void:
	#print("run.gd _on_shop_entered()")
	var shop := _change_view(SHOP_SCN) as Shop
	shop.run = self
	shop.player_data = player_data
	shop.run_account = account
	shop.arcana_system = arcana_system
	shop.arcana_catalog = arcana_catalog
	shop.arcana_reward_pool = player_data.arcana_reward_pool
	Events.request_shop_modifiers.emit(shop)
	shop.populate_shop()

func _on_battle_won() -> void:
	var rewards_scn := _change_view(BATTLE_REWARDS_SCN) as BattleRewardsScreen
	rewards_scn.run_account = account
	rewards_scn.player_data = player_data
	
	#TEMPORARY TEST CODE WHERE REWARDS SHOULD BE GENERATED BY BATTLE DATA
	rewards_scn.add_gold_reward(map.last_room.battle_data.roll_gold_reward())
	rewards_scn.add_card_reward()

func _on_treasure_room_entered() -> void:
	var treasure_scn := _change_view(TREASURE_SCN) as TreasureRoom
	treasure_scn.arcanum_system = arcana_system
	treasure_scn.player_data = player_data
	treasure_scn.generate_arcanum()

func _on_treasure_room_exited(arcanum: Arcanum) -> void:
	var reward_scn := _change_view(BATTLE_REWARDS_SCN) as BattleRewardsScreen
	reward_scn.run_account = account
	reward_scn.player_data = player_data
	reward_scn.arcanum_system = arcana_system
	
	reward_scn.add_arcanum_reward(arcanum)

func _on_map_exited(room: Room) -> void:
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
	
func get_modifier_tokens_for(target: Node) -> Array[ModifierToken]:
	#print("run.gd get_modifier_tokens()")
	var tokens: Array[ModifierToken] = []
	
	# 1. Arcana (global, persistent)
	tokens.append_array(arcana_system.get_modifier_tokens_for(target))
	
	# 2. Combat-only tokens (if in battle)
	var battle_scene := _get_active_battle_scene()
	if battle_scene and target is Fighter:
		tokens.append_array(battle_scene.get_modifier_tokens_for(target))
	
	#for token: ModifierToken in tokens:
		#print("run.gd get_modifier_tokens() token owner: %s" % token.owner)
	# 3. Future: map effects, curses, difficulty scaling, etc.
	
	return tokens

func _get_active_battle_scene() -> BattleScene:
	var view: Node = current_view.get_child(0)
	if view is Battle:
		return view.battle_scene
	return null
	
func _on_modifier_tokens_changed(mod_type: Modifier.Type) -> void:
	if current_view.get_child_count() == 0:
		return
	
	var view := current_view.get_child(0)
	
	if view.has_method("on_modifier_tokens_changed"):
		view.on_modifier_tokens_changed(mod_type)
