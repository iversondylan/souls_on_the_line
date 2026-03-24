# battle.gd

class_name Battle extends Node

const FRIENDLY := 0
const ENEMY := 1


# -------------------------
# Inspector
# -------------------------

@export var debug_mode: bool = true:
	set(value):
		if !is_node_ready():
			await ready
		debug_mode = value
		$Debug_UI.visible = debug_mode

@export var music: AudioStream
@export var battle_data: BattleData

@export var idle_delay_sec: float = 1.0
@export var idle_cooldown_sec: float = 6.0


# -------------------------
# Scene refs
# -------------------------

@onready var sim_host: SimHost = $SimHost
@onready var battle_view: BattleView = $BattleView

@onready var perspective_card_scn: PackedScene = preload("res://scenes/perspective_card.tscn")

@onready var draw_view_overlay: CardsViewWindow = $Visual_Overlays/DrawViewWindow
@onready var discard_view_overlay: CardsViewWindow = $Visual_Overlays/DiscardViewWindow
@onready var collection_view_overlay: CardsViewWindow = $Visual_Overlays/CollectionViewWindow

@onready var mana_panel: ManaPanel = $Battle_UI/ManaPanel
@onready var selection_prompt: SelectionPrompt = $Battle_UI/SelectionPrompt
@onready var battle_interaction_handler: BattleInteractionHandler = $BattleInteractionHandler

var battle_preview_coordinator: BattlePreviewCoordinator

@onready var hand: Hand = $Battle_UI/Hand
@onready var battle_ui: BattleUI = $Battle_UI

@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton

@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView
@onready var turn_phase_title: TurnPhaseTitle = $Battle_UI/TurnPhaseTitle

@onready var thank_you_box: Node2D = $Battle_UI/ThankYouBox


# -------------------------
# Runtime data
# -------------------------

var player_data: PlayerData
var deck: Deck : set = _set_deck
var run: Run : set = _set_run
var run_seed: int
var battle_seed: int
var my_arcana: Array[StringName]

var wait_for_anims: bool = false
var _player_end_turn_armed: bool = false


# -------------------------
# Ready / setup
# -------------------------

func _ready() -> void:
	battle_view.sim_host = sim_host
	battle_view.battle_ui = battle_ui

	hand.battle_view = battle_view
	hand.sim_host = sim_host
	hand.api = sim_host.get_main_api()

	battle_interaction_handler.setup(self)

	battle_preview_coordinator = BattlePreviewCoordinator.new()
	battle_preview_coordinator.name = "BattlePreviewCoordinator"
	battle_preview_coordinator.sim_host = sim_host
	battle_preview_coordinator.battle_view = battle_view
	battle_preview_coordinator.turn_phase_title = turn_phase_title
	add_child(battle_preview_coordinator)

	_connect_events()
	_connect_ui()

	battle_ui.set_end_turn_enabled(false)

	get_tree().paused = false
	set_process(true)


func _connect_events() -> void:
	Events.hand_drawn.connect(_arm_end_turn_button.bind(true))
	Events.hand_drawn.connect(_on_hand_done_drawing)
	Events.dead_combatant_data.connect(_on_dead_combatant_data)
	Events.request_defeat.connect(_on_request_defeat)
	Events.request_victory.connect(_on_request_victory)
	Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)
	Events.mana_view_update.connect(_on_mana_view_update)
	Events.turn_status_view_changed.connect(_on_turn_status_view_changed)


func _connect_ui() -> void:
	draw_pile_button.pressed.connect(
		draw_pile_view.show_current_draw_view.bind("Draw Pile", true)
	)
	discard_pile_button.pressed.connect(
		discard_pile_view.show_current_discard_view.bind("Discard Pile")
	)


# -------------------------
# External wiring
# -------------------------

func _set_run(new_run: Run) -> void:
	run = new_run
	if !is_node_ready():
		await ready

	# Structural ownership lives in SimHost.
	sim_host.status_catalog = run.status_catalog
	sim_host.arcana_catalog = run.arcanum_catalog

	# View still needs direct catalog access for status presentation.
	battle_view.status_catalog = run.status_catalog


func _set_deck(new_deck: Deck) -> void:
	deck = new_deck
	hand.deck = deck


func _runtime() -> SimRuntime:
	return sim_host.get_main_runtime()


# -------------------------
# Battle start
# -------------------------

func start_battle() -> void:
	var resolved_battle_seed := 0
	var resolved_run_seed := 0

	if run != null:
		if "battle_seed" in run:
			resolved_battle_seed = int(run.battle_seed)
		if "run_seed" in run:
			resolved_run_seed = int(run.run_seed)

	sim_host.init_from_seeds(resolved_battle_seed, resolved_run_seed)

	hand.api = sim_host.get_main_api()
	draw_pile_view.api = sim_host.get_main_api() if "api" in draw_pile_view else null
	discard_pile_view.api = sim_host.get_main_api() if "api" in discard_pile_view else null

	sim_host.seed_arcana_from_ids(my_arcana)

	battle_view.bind_log(sim_host.get_event_log())
	battle_view.start_playback()

	sim_host.start_setup()

	wait_for_anims = true

	_spawn_from_battle_data()

	hand.empty_hand()
	deck.reset()
	deck.make_draw_pile()
	MusicPlayer.play(music, true)
	initialize_card_pile_ui()

	sim_host.end_setup()

	var runtime := _runtime()
	if runtime != null:
		runtime.start_group_turn(FRIENDLY, true)


func _spawn_from_battle_data() -> void:
	var runtime := _runtime()
	if runtime == null:
		return

	if player_data != null:
		player_data.alive = true
		#hand.player_data = player_data
		runtime.add_combatant_from_data(player_data, FRIENDLY, 0, true)

	if battle_data == null:
		thank_you_box.show()
		return

	for enemy_data: CombatantData in battle_data.enemies:
		if enemy_data == null:
			continue

		var new_data: CombatantData = enemy_data.duplicate()
		new_data.init()
		runtime.add_combatant_from_data(new_data, ENEMY, -1, false)


func initialize_card_pile_ui() -> void:
	draw_pile_button.card_pile = deck.draw_pile
	draw_pile_view.card_pile = deck.draw_pile
	draw_pile_view.deck = deck

	discard_pile_button.card_pile = deck.discard_pile
	discard_pile_view.card_pile = deck.discard_pile
	discard_pile_view.deck = deck


# -------------------------
# Turn flow / player input
# -------------------------

func _on_end_turn_pressed() -> void:
	if wait_for_anims:
		return
	Events.end_turn_button_pressed.emit()


func _on_end_turn_button_pressed() -> void:
	if wait_for_anims:
		return
	if !_player_end_turn_armed:
		return

	_arm_end_turn_button(false)

	# The hand discard animation is view-driven.
	# Runtime does not advance the player end handshake until this completes.
	if !Events.hand_discarded.is_connected(_on_hand_discarded_one_shot):
		Events.hand_discarded.connect(_on_hand_discarded_one_shot, CONNECT_ONE_SHOT)

	var runtime := _runtime()
	if runtime != null:
		runtime.request_player_end()


func _on_hand_discarded_one_shot() -> void:
	var runtime := _runtime()
	if runtime != null:
		runtime.notify_player_discard_animation_finished()


func _on_hand_done_drawing() -> void:
	wait_for_anims = false


func _arm_end_turn_button(armed: bool) -> void:
	_player_end_turn_armed = armed
	battle_ui.set_end_turn_enabled(armed)


# -------------------------
# Event reactions
# -------------------------

func _on_mana_view_update(o: ManaViewOrder) -> void:
	if o == null:
		return
	if mana_panel == null:
		return

	# For now just set current mana.
	# Later you can add a max label and use o.after_max_mana too.
	mana_panel.set_mana(o.after_mana)

func _on_turn_status_view_changed(group_index: int, active_id: int, _pending_ids: PackedInt32Array, player_id: int) -> void:
	if turn_phase_title == null:
		return

	var text := ""
	if active_id > 0 and active_id == player_id:
		text = "Player Turn"
	elif int(group_index) == FRIENDLY:
		text = "Friendly Turn"
	elif int(group_index) == ENEMY:
		text = "Enemy Turn"
	else:
		text = "Turn"

	turn_phase_title.update_turn_text(text)

func _on_dead_combatant_data(combatant_data: CombatantData) -> void:
	if player_data != null and combatant_data == player_data:
		Events.request_defeat.emit()


func _on_summon_reserve_card_released(summoned_id: int, card_uid: String) -> void:
	if deck != null:
		deck.discard_reserved_summon_card(card_uid)

	var combatant_view := battle_view.get_combatant(summoned_id) if battle_view != null else null
	if combatant_view == null or discard_pile_button == null:
		return

	var perspective_card: PerspectiveCard = perspective_card_scn.instantiate()
	battle_ui.add_child(perspective_card)

	var start := combatant_view.global_position
	start.y -= 200.0

	var finish := discard_pile_button.global_position
	perspective_card.zoom_card(start, finish)


func _on_request_defeat() -> void:
	Events.battle_over_screen_requested.emit("YOU DIED", BattleOverPanel.Outcome.LOSE)


func _on_request_victory() -> void:
	Events.battle_over_screen_requested.emit("PATH CLEARED", BattleOverPanel.Outcome.WIN)


# -------------------------
# Debug
# -------------------------

func _on_dump_events_button_pressed() -> void:
	sim_host.debug_dump_events()


func _on_kill_enemies_button_pressed() -> void:
	sim_host.get_main_runtime().debug_kill_all_enemies()
