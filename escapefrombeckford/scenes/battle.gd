class_name Battle extends Node2D

@export var debug_mode: bool = true:
	set(value):
		if !is_node_ready():
			await ready
		debug_mode = value
		$Debug_UI.visible = debug_mode
@export var music: AudioStream
@export var battle_data: BattleData


@onready var player_scn: PackedScene = preload("res://scenes/turn_takers/player.tscn")
@onready var enemy_scn: PackedScene = preload("res://scenes/turn_takers/enemy.tscn")
@onready var perspective_card_scn: PackedScene = preload("res://scenes/perspective_card.tscn")

@onready var draw_view_overlay: CardsViewWindow = $Visual_Overlays/DrawViewWindow
@onready var discard_view_overlay: CardsViewWindow = $Visual_Overlays/DiscardViewWindow
@onready var collection_view_overlay: CardsViewWindow = $Visual_Overlays/CollectionViewWindow
#@onready var deck_ui: UsableDeckUI = $Battle_UI/UsableDeckUi
@onready var battle_scene: BattleScene = $Battle_Scene
@onready var mana_panel: ManaPanel = $Battle_UI/ManaPanel

@onready var hand = $Battle_UI/Hand
@onready var draw_button: TextureButton = $Battle_UI/DrawButton
@onready var discard_button: TextureButton = $Battle_UI/DiscardButton
@onready var collection_button: TextureButton = $Battle_UI/CollectionButton
@onready var battle_ui: BattleUI = $Battle_UI

@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton

@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView

var player_data: PlayerData
var player: Player
var deck: Deck : set = _set_deck


var mouse_pressed: bool = false
var enemy_character_state: int = 0
#var combatants_mouse_left: Array[Combatant] = []
var wait_for_anims: bool = false

func _ready() -> void:
	get_tree().paused = false
	#CombatantLibrary.compile_combatant_library()
	#IconLibrary.compile_icon_library()
	BattleController.current_state = BattleController.BattleState.PRE_GAME

	#update_game_state()

	Events.dead_combatant_data.connect(_on_dead_combatant_data)
	#Events.need_updated_game_state.connect(_need_updated_game_state)
	Events.battle_group_empty.connect(_on_battle_group_empty)
	Events.player_combatant_data_changed.connect(_on_player_data_changed)
	Events.hand_drawn.connect(_on_hand_drawn)
	Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)
	Events.game_over_started.connect(_on_game_over_started)
	Events.victory_started.connect(_on_victory_started)

	draw_pile_button.pressed.connect(draw_pile_view.show_current_draw_view.bind("Draw Pile", true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_discard_view.bind("Discard Pile"))
	
	hand.battle_scene = battle_scene

func _set_deck(_deck: Deck) -> void:
	deck = _deck
	hand.deck = deck
	battle_scene.deck = deck
	

func initialize_card_pile_ui() -> void:
	#draw_pile_button.deck = deck
	draw_pile_button.card_pile = deck.draw_pile
	
	draw_pile_view.card_pile = deck.draw_pile
	draw_pile_view.deck = deck
	
	#discard_pile_button.deck = deck
	discard_pile_button.card_pile = deck.discard_pile
	
	discard_pile_view.card_pile = deck.discard_pile
	discard_pile_view.deck = deck

func start_battle():
	if wait_for_anims:
		return
	BattleController.current_state = BattleController.BattleState.PRE_GAME
	
	wait_for_anims = true
	
	battle_scene.clear_combatants()
	
	BattleController.is_running = true
	BattleController.turn_number = 0
	
	make_player_combatant()
	make_enemies()
	
	_on_player_data_changed()
	hand.empty_hand()
	deck.reset()
	deck.make_draw_pile()
	initialize_card_pile_ui()
	BattleController.transition(BattleController.BattleState.FRIENDLY_TURN)
	MusicPlayer.play(music, true)

func make_player_combatant() -> void:
	var new_player: Player = player_scn.instantiate()
	battle_scene.add_combatant(new_player, 0, 0)
	new_player.combatant_data = player_data
	player_data.is_alive = true
	battle_scene.set_player(new_player)
	player = new_player
	hand.player = new_player

func make_enemies() -> void:
	if !battle_data:
		print("battle.gd make_enemies() Error: no battle_data")
		return
	for enemy_data: CombatantData in battle_data.enemies:
		var new_enemy: Enemy = enemy_scn.instantiate()
		var new_enemy_index: int = battle_scene.get_n_combatants_in_group(1)
		battle_scene.add_combatant(new_enemy, 1, new_enemy_index)

		new_enemy.combatant_data = enemy_data.duplicate()
		
		new_enemy.reset()
		new_enemy.update_action()
	

#func update_game_state():
	#pass
	#GameState.combatants = battle_scene.get_combatants()
	#if GameState.player != battle_scene.get_player():
		#GameState.player = battle_scene.get_player()
	#GameState.turn_number = BattleController.turn_number

#func _process(_delta: float) -> void:
	#if !BattleController.is_running:
		#mouse_pressed = false
		#return
	#
	#if mouse_pressed && !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#mouse_pressed = false

#func _input(event):
	#if event.is_action("restart"):
		#start_battle()
	#elif event.is_action_pressed("mouse_click"):
		##hand.on_click()
		#mouse_pressed = true

#func _on_take_1_button_pressed() -> void:
	#pass
	#GameState.player.combatant_data.max_mana_red += 1
	#GameState.player.combatant_data.max_mana_green += 1
	#GameState.player.combatant_data.max_mana_blue += 1

func _on_take_6_button_pressed() -> void:
	pass
	#player.take_damage(6)

func _on_end_turn_pressed() -> void:
	if wait_for_anims:
		return
	Events.end_turn_button_pressed.emit()

#func _on_draw_button_pressed() -> void:
	#if BattleController.current_cards_view_state == BattleController.CardsViewState.DRAW_VIEW:
		#BattleController.transition_cards_view(BattleController.CardsViewState.NO_CARDS_VIEW)
		#draw_view_overlay.hide_window()
	#elif BattleController.current_cards_view_state == BattleController.CardsViewState.NO_CARDS_VIEW:
		#BattleController.transition_cards_view(BattleController.CardsViewState.DRAW_VIEW)
		#draw_view_overlay.show_window(Deck.get_draw_cards())

#func _on_discard_button_pressed() -> void:
	#if BattleController.current_cards_view_state == BattleController.CardsViewState.DISCARD_VIEW:
		#BattleController.transition_cards_view(BattleController.CardsViewState.NO_CARDS_VIEW)
		#discard_view_overlay.hide_window()
	#elif BattleController.current_cards_view_state == BattleController.CardsViewState.NO_CARDS_VIEW:
		#BattleController.transition_cards_view(BattleController.CardsViewState.DISCARD_VIEW)
		#discard_view_overlay.show_window(Deck.get_discards())

#func _on_collection_button_pressed() -> void:
	#if BattleController.current_cards_view_state == BattleController.CardsViewState.COLLECTION_VIEW:
		#BattleController.transition_cards_view(BattleController.CardsViewState.NO_CARDS_VIEW)
		#collection_view_overlay.hide_window()
	#elif BattleController.current_cards_view_state == BattleController.CardsViewState.NO_CARDS_VIEW:
		#BattleController.transition_cards_view(BattleController.CardsViewState.COLLECTION_VIEW)
		#collection_view_overlay.show_window(Deck.make_all_cards_from_collection())

func _on_start_battle_button_pressed() -> void:
	start_battle()

func _on_usable_deck_ui_pressed() -> void:
	pass
	#draw_card()

func draw_card():
	pass
	#var card_with_id = deck_ui.draw_card()
	#if card_with_id:
		#hand.add_card(card_with_id)

func _on_add_attack_button_pressed() -> void:
	pass
	#Deck.add_card(CardLibrary.card_library[0].duplicate())

func _on_add_defend_button_pressed() -> void:
	pass
	#Deck.add_card(CardLibrary.card_library[1].duplicate())

func _on_add_basic_deck_button_pressed() -> void:
	pass
	#for i in range(5):
		#Deck.add_card(CardLibrary.card_library[0].duplicate())
		#Deck.add_card(CardLibrary.card_library[1].duplicate())
		#Deck.add_card(CardLibrary.card_library[2].duplicate())
		#Deck.add_card(CardLibrary.card_library[3].duplicate())

func _on_remove_card_button_pressed() -> void:
	pass
	#if Deck.make_all_cards_from_collection().is_empty():
		#return
	#var random_card: CardWithID = Deck.make_all_cards_from_collection().pick_random()
	#Deck.remove_card(random_card.id)

func _on_player_data_changed() -> void:
	if player:
		mana_panel.red_mana = player.combatant_data.mana_red
		mana_panel.green_mana = player.combatant_data.mana_green
		mana_panel.blue_mana = player.combatant_data.mana_blue

func _on_hand_drawn() -> void:
	wait_for_anims = false

func _on_dead_combatant_data(combatant_data: CombatantData):
	if combatant_data == player.combatant_data:
		BattleController.transition(BattleController.BattleState.GAME_OVER)

func _on_battle_group_empty(_battle_group: BattleGroup) -> void:
	if _battle_group is BattleGroupEnemy:
		BattleController.transition(BattleController.BattleState.VICTORY)

func _on_summon_reserve_card_released(summoned_ally: SummonedAlly) -> void:
	var perspective_card: PerspectiveCard = perspective_card_scn.instantiate()
	battle_ui.add_child(perspective_card)
	perspective_card.zoom_card(summoned_ally.global_position + Vector2(0, -summoned_ally.combatant_data.height/2.0), discard_pile_button.global_position)

func _on_game_over_started():
	#print("main.gd _on_game_over_started()")
	Events.battle_over_screen_requested.emit("YOU DIED", BattleOverPanel.Outcome.LOSE)

func _on_victory_started():
	#print("main.gd _on_victory_started()")
	Events.battle_over_screen_requested.emit("PATH CLEARED", BattleOverPanel.Outcome.WIN)


func _on_kill_enemies_button_pressed() -> void:
	battle_scene.kill_enemies()
