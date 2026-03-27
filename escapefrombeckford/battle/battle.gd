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

@onready var perspective_card_scn: PackedScene = preload("res://battle/view/perspective_card.tscn")

@onready var draw_view_overlay: CardsViewWindow = $Visual_Overlays/DrawViewWindow
@onready var discard_view_overlay: CardsViewWindow = $Visual_Overlays/DiscardViewWindow
@onready var collection_view_overlay: CardsViewWindow = $Visual_Overlays/CollectionViewWindow

@onready var mana_panel: ManaPanel = $Battle_UI/ManaPanel
@onready var selection_prompt: SelectionPrompt = $Battle_UI/SelectionPrompt
@onready var battle_interaction_handler: BattleInteractionHandler = $BattleInteractionHandler
@onready var battle_preview_coordinator: BattlePreviewCoordinator = $BattlePreviewCoordinator


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
var run_state: RunState
var run_deck: RunDeck : set = _set_run_deck
var run: Run : set = _set_run
var run_seed: int
var battle_seed: int
var my_arcana: Array[StringName]

var wait_for_anims: bool = false
var _player_end_turn_armed: bool = false
var card_bins: BattleCardBins
var card_bin_rule_host: CardBinRuleHost


# -------------------------
# Ready / setup
# -------------------------

func _ready() -> void:
	_ensure_card_bins()

	battle_view.sim_host = sim_host
	battle_view.battle_ui = battle_ui

	hand.battle_view = battle_view
	hand.sim_host = sim_host
	hand.api = sim_host.get_main_api()

	battle_interaction_handler.setup(self)

	battle_preview_coordinator.sim_host = sim_host
	battle_preview_coordinator.battle_view = battle_view
	battle_preview_coordinator.turn_phase_title = turn_phase_title

	_connect_events()
	_connect_ui()

	battle_ui.set_end_turn_enabled(false)

	get_tree().paused = false
	set_process(true)


func _connect_events() -> void:
	Events.dead_combatant_data.connect(_on_dead_combatant_data)
	Events.request_defeat.connect(_on_request_defeat)
	Events.request_victory.connect(_on_request_victory)
	Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)
	Events.player_input_view_reached.connect(_on_player_input_view_reached)
	Events.mana_view_update.connect(_on_mana_view_update)
	Events.turn_status_view_changed.connect(_on_turn_status_view_changed)


func _connect_ui() -> void:
	draw_pile_button.pressed.connect(
		draw_pile_view.show_current_view.bind("Draw Pile", true)
	)
	discard_pile_button.pressed.connect(
		discard_pile_view.show_current_view.bind("Discard Pile")
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


func _set_run_deck(new_run_deck: RunDeck) -> void:
	run_deck = new_run_deck
	if is_node_ready():
		_ensure_card_bins()


func _runtime() -> SimRuntime:
	return sim_host.get_main_runtime()


func _ensure_card_bins() -> void:
	if card_bins == null:
		card_bins = BattleCardBins.new()
		card_bins.name = "BattleCardBins"
		add_child(card_bins)
	if card_bin_rule_host == null:
		card_bin_rule_host = CardBinRuleHost.new()
	card_bins.setup(self, hand)
	card_bins.rule_host = card_bin_rule_host


# -------------------------
# Battle start
# -------------------------

func start_battle() -> void:
	var resolved_battle_seed := int(battle_seed)
	var resolved_run_seed := int(run_seed)

	if resolved_battle_seed == 0 and run != null and "battle_seed" in run:
		resolved_battle_seed = int(run.battle_seed)
	if resolved_run_seed == 0 and run != null and "run_seed" in run:
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
	if card_bins != null:
		card_bins.configure_seed(resolved_battle_seed)
		card_bins.reset_bins()
		if run_deck != null and run_deck.card_collection != null:
			card_bins.seed_card_collection(run_deck.card_collection)
		card_bins.make_draw_pile()
	MusicPlayer.play(music, true)
	initialize_card_pile_ui()

	sim_host.end_setup()

	var runtime := _runtime()
	if runtime != null:
		runtime.begin_group_turn_flow(FRIENDLY, true)


func _spawn_from_battle_data() -> void:
	var runtime := _runtime()
	if runtime == null:
		return

	if player_data != null:
		var current_health := _get_player_spawn_health()
		runtime.add_combatant_from_data(player_data, FRIENDLY, 0, true, current_health)

	if battle_data == null:
		thank_you_box.show()
		return

	for enemy_data: CombatantData in battle_data.enemies:
		if enemy_data == null:
			continue

		var new_data: CombatantData = enemy_data.duplicate()
		runtime.add_combatant_from_data(new_data, ENEMY, -1, false)


func initialize_card_pile_ui() -> void:
	if card_bins == null:
		return
	draw_pile_button.card_pile = card_bins.state.draw_pile
	draw_pile_view.card_pile = card_bins.state.draw_pile

	discard_pile_button.card_pile = card_bins.state.discard_pile
	discard_pile_view.card_pile = card_bins.state.discard_pile


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
	wait_for_anims = true

	var runtime := _runtime()
	if runtime != null:
		runtime.request_player_end()
	var api := sim_host.get_main_api() if sim_host != null else null
	if card_bins == null or card_bin_rule_host == null or api == null:
		return
	var cleanup_ctx := card_bin_rule_host.build_player_end_cleanup_context(int(api.get_player_id()))
	await card_bins.request_hand_cleanup(cleanup_ctx)
	if runtime != null:
		runtime.confirm_player_end_ready()


func _on_player_input_view_reached(player_id: int) -> void:
	var api := sim_host.get_main_api() if sim_host != null else null
	if api == null:
		return
	if int(player_id) <= 0 or int(player_id) != int(api.get_player_id()):
		return
	if card_bins == null or card_bin_rule_host == null:
		return

	wait_for_anims = true
	var draw_ctx := card_bin_rule_host.build_player_turn_refill_context(int(player_id))
	await card_bins.request_draw(draw_ctx)
	Events.hand_drawn.emit()
	_arm_end_turn_button(true)
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
	if card_bins != null:
		card_bins.discard_reserved_summon_card(card_uid)

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

func get_player_current_health() -> int:
	var api := sim_host.get_main_api() if sim_host != null else null
	if api == null or api.state == null:
		return _get_player_spawn_health()
	var player_id := int(api.get_player_id())
	if player_id <= 0:
		return _get_player_spawn_health()
	var unit := api.state.get_unit(player_id)
	if unit == null:
		return _get_player_spawn_health()
	return int(unit.health)

func _get_player_spawn_health() -> int:
	if run_state != null and run_state.player_run_state != null:
		return int(run_state.player_run_state.current_health)
	return int(player_data.max_health) if player_data != null else 0


# -------------------------
# Debug
# -------------------------

func _on_dump_events_button_pressed() -> void:
	sim_host.debug_dump_events()


func _on_kill_enemies_button_pressed() -> void:
	sim_host.get_main_runtime().debug_kill_all_enemies()


func _on_validate_scope_nesting_pressed() -> void:
	if sim_host == null:
		push_warning("Battle._on_validate_scope_nesting_pressed(): missing sim_host")
		return

	var log := sim_host.get_event_log()
	if log == null:
		push_warning("Battle._on_validate_scope_nesting_pressed(): missing event log")
		return

	var report := log.validate_scope_nesting()
	if report == null:
		push_warning("Battle._on_validate_scope_nesting_pressed(): validator returned null report")
		return

	if report.is_valid():
		print("ValidateScopeNesting: PASS")
		return

	push_warning("ValidateScopeNesting: FAIL")
	print(report.to_debug_string())
