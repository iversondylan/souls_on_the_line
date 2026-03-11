# battle.gd (SIM/VIEW only)

class_name Battle extends Node

const FRIENDLY := 0
const ENEMY := 1

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

@onready var sim_host: SimHost = $SimHost
@onready var battle_view: BattleView = $BattleView

@onready var perspective_card_scn: PackedScene = preload("res://scenes/perspective_card.tscn")

@onready var draw_view_overlay: CardsViewWindow = $Visual_Overlays/DrawViewWindow
@onready var discard_view_overlay: CardsViewWindow = $Visual_Overlays/DiscardViewWindow
@onready var collection_view_overlay: CardsViewWindow = $Visual_Overlays/CollectionViewWindow

@onready var mana_panel: ManaPanel = $Battle_UI/ManaPanel
@onready var selection_prompt: SelectionPrompt = $Battle_UI/SelectionPrompt
@onready var battle_interaction_handler: BattleInteractionHandler = $BattleInteractionHandler

@onready var hand: Hand = $Battle_UI/Hand
@onready var battle_ui: BattleUI = $Battle_UI

@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton

@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView

@onready var thank_you_box: Node2D = $Battle_UI/ThankYouBox

var player_data: PlayerData
var deck: Deck : set = _set_deck
var run: Run : set = _set_run
var run_seed : int
var battle_seed: int
var my_arcana: Array[StringName]

var wait_for_anims: bool = false
var _player_end_turn_armed: bool = false

func _ready() -> void:
	battle_view.sim_host = sim_host
	battle_view.battle_ui = battle_ui

	Events.hand_drawn.connect(_arm_end_turn_button.bind(true))
	Events.hand_drawn.connect(_on_hand_done_drawing)
	Events.dead_combatant_data.connect(_on_dead_combatant_data)
	Events.request_defeat.connect(_on_request_defeat)
	Events.request_victory.connect(_on_request_victory)
	Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)

	draw_pile_button.pressed.connect(draw_pile_view.show_current_draw_view.bind("Draw Pile", true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_discard_view.bind("Discard Pile"))

	hand.battle_view = battle_view
	hand.sim_host = sim_host
	battle_interaction_handler.setup(self)
	
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)
	
	# Optional: start with End Turn disabled until we draw
	battle_ui.set_end_turn_enabled(false)
	
	get_tree().paused = false
	set_process(true)

func _set_run(new_run: Run) -> void:
	run = new_run
	if !is_node_ready():
		await ready

	# Provide catalogs to SIM + VIEW
	sim_host.status_catalog = run.status_catalog
	sim_host.arcana_catalog = run.arcanum_catalog
	battle_view.status_catalog = run.status_catalog

func _set_deck(_deck: Deck) -> void:
	deck = _deck
	hand.deck = deck

func initialize_card_pile_ui() -> void:
	draw_pile_button.card_pile = deck.draw_pile
	draw_pile_view.card_pile = deck.draw_pile
	draw_pile_view.deck = deck

	discard_pile_button.card_pile = deck.discard_pile
	discard_pile_view.card_pile = deck.discard_pile
	discard_pile_view.deck = deck

func start_battle() -> void:
	# Seeds: take them from wherever you're currently authoring them.
	# If you still store them in Run/BattleData, swap these lines accordingly.
	var battle_seed := 0
	var run_seed := 0
	if run != null:
		if "battle_seed" in run:
			battle_seed = int(run.battle_seed)
		if "run_seed" in run:
			run_seed = int(run.run_seed)
	
	sim_host.init_from_seeds(battle_seed, run_seed)
	
	# ids are the .get_id()'s of currently owned arcana
	sim_host.seed_arcana_from_ids(my_arcana)
	
	# VIEW follows event log playback
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
	
	# NOTE: "Huge success."
	# SIM is authoritative; VIEW follows BattleEventLog playback.
	# Live Fighters are out of the loop (RIP).
	sim_host.end_setup()
	sim_host.start_group_turn(0, true)

func _spawn_from_battle_data() -> void:
	if player_data != null:
		player_data.alive = true
		hand.player_data = player_data
		sim_host.add_combatant_from_data(player_data, FRIENDLY, 0, true)
	
	if battle_data == null:
		thank_you_box.show()
		return
	
	for enemy_data: CombatantData in battle_data.enemies:
		if enemy_data == null:
			continue
		var new_data: CombatantData = enemy_data.duplicate()
		new_data.init()
		sim_host.add_combatant_from_data(new_data, ENEMY, -1, false)

func _on_end_turn_pressed() -> void:
	if wait_for_anims:
		return
	Events.end_turn_button_pressed.emit()

func _on_end_turn_button_pressed() -> void:
	# UI pressed End Turn; drive SIM.
	if wait_for_anims:
		return
	if !_player_end_turn_armed:
		return

	_arm_end_turn_button(false)

	# Hand discard is a UX animation; notify SIM when it's done.
	if !Events.hand_discarded.is_connected(_on_hand_discarded_one_shot):
		Events.hand_discarded.connect(_on_hand_discarded_one_shot, CONNECT_ONE_SHOT)

	# Ask SIM to end the player's turn (TurnEngineCore lives in SimHost now).
	sim_host.request_player_end()

func _on_hand_discarded_one_shot() -> void:
	# Your SimHost already has the hook (per your earlier code)
	sim_host.hand_discarded()

func _on_hand_done_drawing() -> void:
	wait_for_anims = false

func _arm_end_turn_button(armed: bool) -> void:
	_player_end_turn_armed = armed
	battle_ui.set_end_turn_enabled(armed)

func _on_dead_combatant_data(combatant_data: CombatantData) -> void:
	if player_data != null and combatant_data == player_data:
		Events.request_defeat.emit()

func _on_summon_reserve_card_released(summoned_id: int, card_uid: String) -> void:
	# 1) Move reserved card into discard pile (data truth for your deck UI)
	if deck != null:
		deck.discard_reserved_summon_card(card_uid)

	# 2) Animate the “card flies to discard pile”
	var v := battle_view.get_combatant(summoned_id) if battle_view != null else null
	if v == null or discard_pile_button == null:
		return

	var perspective_card: PerspectiveCard = perspective_card_scn.instantiate()
	battle_ui.add_child(perspective_card)

	# Start point: unit art top-ish
	var start := v.global_position
	start.y -= 200.0 # or use height if you want

	var end := discard_pile_button.global_position
	perspective_card.zoom_card(start, end)

func _on_request_defeat() -> void:
	Events.battle_over_screen_requested.emit("YOU DIED", BattleOverPanel.Outcome.LOSE)

func _on_request_victory() -> void:
	Events.battle_over_screen_requested.emit("PATH CLEARED", BattleOverPanel.Outcome.WIN)

func _on_dump_states_button_pressed() -> void:
	sim_host.debug_dump_orders()
	sim_host.debug_dump_units()

func _on_dump_events_button_pressed() -> void:
	sim_host.debug_dump_events()

## battle.gd
#
#class_name Battle extends Node
#
#const FRIENDLY := 0
#const ENEMY := 1
#
#@export var debug_mode: bool = true:
	#set(value):
		#if !is_node_ready():
			#await ready
		#debug_mode = value
		#$Debug_UI.visible = debug_mode
#@export var music: AudioStream
#@export var battle_data: BattleData
#
#@export var idle_delay_sec: float = 1.0
#@export var idle_cooldown_sec: float = 6.0
#@onready var sim_host: SimHost = $SimHost
#@onready var battle_view: BattleView = $BattleView
#
#@onready var player_scn: PackedScene = preload("res://scenes/turn_takers/player.tscn")
#@onready var enemy_scn: PackedScene = preload("res://scenes/turn_takers/enemy.tscn")
#@onready var perspective_card_scn: PackedScene = preload("res://scenes/perspective_card.tscn")
#
#@onready var draw_view_overlay: CardsViewWindow = $Visual_Overlays/DrawViewWindow
#@onready var discard_view_overlay: CardsViewWindow = $Visual_Overlays/DiscardViewWindow
#@onready var collection_view_overlay: CardsViewWindow = $Visual_Overlays/CollectionViewWindow
#@onready var battle_scene: BattleScene = $Battle_Scene
#@onready var mana_panel: ManaPanel = $Battle_UI/ManaPanel
#@onready var selection_prompt: SelectionPrompt = $Battle_UI/SelectionPrompt
#
#
#@onready var hand: Hand = $Battle_UI/Hand
#@onready var battle_ui: BattleUI = $Battle_UI
#
#@onready var draw_pile_button: CardPileOpener = %DrawPileButton
#@onready var discard_pile_button: CardPileOpener = %DiscardPileButton
#
#@onready var draw_pile_view: CardPileView = %DrawPileView
#@onready var discard_pile_view: CardPileView = %DiscardPileView
#@onready var _spark: TurnOrderSparkController = $Battle_UI/TurnOrderSparkController
#@onready var turn_phase_title: TurnPhaseTitle = $Battle_UI/TurnPhaseTitle
#
#@onready var thank_you_box: Node2D = $Battle_UI/ThankYouBox
#
#var player_data: PlayerData
#var player: Player
#var deck: Deck : set = _set_deck
#var run: Run : set = _set_run
#var arcana: ArcanaSystem
#var arcana_catalog: ArcanaCatalog
#var my_arcana: Array[StringName]
#var mouse_pressed: bool = false
#var enemy_character_state: int = 0
#var wait_for_anims: bool = false
#
#var run_seed: int
#var battle_seed: int
#
#var api: LiveBattleAPI
#var host : TurnEngineHostLive
#var turn_engine : TurnEngineCore
#
##var _pending_start_engine_group: int = -1
##var _pending_start_engine_start_at_player: bool = false
#var _player_end_turn_armed: bool = false
##var _awaiting_player_discard: bool = false
#
#var _arcana_gate: Variant = null # GDScriptFunctionState or Signal or null
#var _arcana_gate_seq: int = 0    # monotonic token to avoid “old gate clears new 
#
#func _ready() -> void:
	#
	#battle_view.sim_host = sim_host
	#battle_view.battle_ui = battle_ui
	#Events.hand_drawn.connect(_arm_end_turn_button.bind(true))
	#
	##print_tree_pretty()
	#api = LiveBattleAPI.new(battle_scene)
	#host = TurnEngineHostLive.new(self)
	#turn_engine = TurnEngineCore.new(host)
	#turn_engine.player_begin_requested.connect(_on_player_begin_requested)
	#api.turn_engine = turn_engine
	#battle_scene.api = api
	#battle_scene.sim_host = sim_host
	#turn_engine.actor_requested.connect(_on_actor_requested)
	#turn_engine.group_turn_ended.connect(_on_group_turn_ended)
	#turn_engine.pending_view_changed.connect(_on_pending_view_changed)
	#turn_engine.arcana_proc_requested.connect(_on_arcana_proc_requested)
	##turn_engine.player_end_requested.connect(_on_player_end_requested)
	#Events.live_battle_api_created.emit(api)
	#set_process(true)
	#
	#
	#Events.hand_drawn.connect(_enable_preview_turn_flow_button) 
	#Events.player_turn_completed.connect(_cancel_turn_order_spark)
	#Events.player_turn_completed.connect(_disable_preview_turn_flow_button)
	##Events.player_turn_completed.connect(_on_player_turn_completed)
	#Events.end_turn_button_pressed.connect(_cancel_turn_order_spark)
	#Events.end_turn_button_pressed.connect(_disable_preview_turn_flow_button)
	#turn_phase_title.preview_button_pressed.connect(_try_start_turn_order_spark)
	#Events.fighter_entered_turn.connect(_on_fighter_entered_turn)
	#
	#get_tree().paused = false
	##BattleController.current_state = BattleController.BattleState.PRE_GAME
	#Events.dead_combatant_data.connect(_on_dead_combatant_data)
	#Events.battle_group_empty.connect(_on_battle_group_empty)
	#Events.player_combatant_data_changed.connect(_on_player_data_changed)
	#Events.hand_drawn.connect(_on_hand_drawn)
	#
	## Temporary v
	##battle_scene.runner.scope_drained.connect(_on_runner_scope_drained)
	##Events.hand_drawn.connect(simulate_battle)
	## Temporary ^
	#
	#Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)
	#Events.request_defeat.connect(_on_request_defeat)
	#Events.request_victory.connect(_on_request_victory)
	##Events.request_activate_arcana_by_type.connect(_on_request_activate_arcana_by_type)
	##Events.request_enemy_turn.connect(_on_request_enemy_turn)
	##Events.request_friendly_turn.connect(_on_request_friendly_turn)
	##Events.arcana_activated.connect(_on_arcana_activated)
	##Events.request_draw_hand.connect(_on_request_hand_draw)
	#
	#draw_pile_button.pressed.connect(draw_pile_view.show_current_draw_view.bind("Draw Pile", true))
	#discard_pile_button.pressed.connect(discard_pile_view.show_current_discard_view.bind("Discard Pile"))
	#
	##hand.battle_scene = battle_scene
	#hand.battle_view = battle_view
	#hand.sim_host = sim_host
	#battle_interaction_handler.setup(self)
	#
	#Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed_live)
	#Events.hand_drawn.connect(_on_hand_done_drawing)
	##Events.hand_discarded.connect(_on_hand_discarded)
	## Optional: start with End Turn disabled until we draw
	#battle_ui.set_end_turn_enabled(false)
#
#func _set_run(new_run: Run) -> void:
	#run = new_run
	#api.status_catalog = run.status_catalog
	#if !is_node_ready():
		#await ready
	#battle_scene.run = run
#
#func _set_deck(_deck: Deck) -> void:
	#deck = _deck
	#hand.deck = deck
	#battle_scene.deck = deck
#
#func initialize_card_pile_ui() -> void:
	#draw_pile_button.card_pile = deck.draw_pile
	#
	#draw_pile_view.card_pile = deck.draw_pile
	#draw_pile_view.deck = deck
	#
	#discard_pile_button.card_pile = deck.discard_pile
	#
	#discard_pile_view.card_pile = deck.discard_pile
	#discard_pile_view.deck = deck
#
#func start_battle():
	#
	#sim_host.init_from_seeds(battle_scene.battle_seed, battle_scene.run_seed)
	#sim_host.status_catalog = run.status_catalog
	#sim_host.arcana_catalog = run.arcanum_catalog
	#battle_view.status_catalog = run.status_catalog
	## ids are the .get_id()'s of currently owned arcana
	#sim_host.seed_arcana_from_ids(my_arcana) #ids: Array[StringName]
	##battle_view.reset_view()
	#battle_view.bind_log(sim_host.get_event_log()) # or sim_host.state.events
	#battle_view.start_playback()
	#
	#sim_host.start_setup()
	#
	#
	#
	##battle_scene.run_seed = run_seed
	##battle_scene.battle_seed = battle_seed
	##if wait_for_anims:
		##return
	##BattleController.current_state = BattleController.BattleState.PRE_GAME
	#
	#wait_for_anims = true
	#
	#battle_scene.clear_combatants()
	#
	#make_player_combatant()
	#make_enemies()
	##Events.battle_reset.emit()
	##battle_scene.build_static_modifiers_from_arcana()
	##Events.initiate_first_intents.emit()
	##_on_player_data_changed()
	#hand.empty_hand()
	#deck.reset()
	#deck.make_draw_pile()
	#MusicPlayer.play(music, true)
	#initialize_card_pile_ui()
	#
	#
	## NOTE: "Huge success."
	## SIM is authoritative; VIEW follows BattleEventLog playback.
	## Live Fighters are out of the loop (RIP).
	#sim_host.end_setup()
	#sim_host.start_group_turn(0, true)
	##BattleController.current_state = BattleController.BattleState.FRIENDLY_TURN
	##await _apply_group_turn_start_hooks_scoped(0)
	##turn_engine.start_group_turn(0, true)
#
#func _on_end_turn_button_pressed_live() -> void:
	#print("battle.gd _on_end_turn_button_pressed_live()")
	#if wait_for_anims:
		#return
	#if !_player_end_turn_armed:
		#return
#
	#_arm_end_turn_button(false)
	#if !Events.hand_discarded.is_connected(_on_hand_discarded_one_shot):
		#Events.hand_discarded.connect(_on_hand_discarded_one_shot, CONNECT_ONE_SHOT)
	#sim_host.request_player_end()
#
#func _on_hand_discarded_one_shot() -> void:
	##print("battle.gd _on_hand_discarded_one_shot()")
	#sim_host.hand_discarded()
#
##func _on_runner_scope_drained(scope: int) -> void:
	##pass
	###print("battle.gd _on_runner_scope_drained() scope: ", scope)
##
##func _on_request_activate_arcana_by_type(type: Arcanum.Type):
	##pass
	###if arcana:
		###arcana.activate_arcana_by_type_async(type, self)
##
##
##func _on_arcana_activated(type: Arcanum.Type) -> void:
	###print("battle.gd _on_arcana_activated() type: ", Arcanum.Type.keys()[type])
	##pass
#
#func _apply_glow_live(active_id: int, pending_ids: PackedInt32Array) -> void:
	## If nothing active, clear glow (or keep last — but clearing is safer)
	###print("battle.gd _apply_glow_live() active_id: %s, pending_ids: %s" % [active_id, pending_ids])
	#if active_id <= 0:
		#_clear_all_pending_glow()
		#return
	#
	#var group_index := host.get_group_index_of(active_id)
	#if group_index < 0:
		#_clear_all_pending_glow()
		#return
	#
	#var group: BattleGroup = battle_scene.get_group_by_index(group_index)
	#if !group or !is_instance_valid(group):
		#_clear_all_pending_glow()
		#return
	#
	## Fast membership check
	#var pending_set := {}
	#for id in pending_ids:
		#pending_set[int(id)] = true
	#
	#for f: Fighter in group.get_combatants(false):
		#if !f or !is_instance_valid(f):
			#continue
		#
		#var cid := int(f.combat_id)
		#if cid == active_id:
			#f.set_pending_turn_glow(Fighter.TurnStatus.TURN_ACTIVE)
		#elif pending_set.has(cid):
			#f.set_pending_turn_glow(Fighter.TurnStatus.TURN_PENDING)
		#else:
			#f.set_pending_turn_glow(Fighter.TurnStatus.NONE)
#
#
#func _clear_all_pending_glow() -> void:
	#for gi in [0, 1]:
		#var g: BattleGroup = battle_scene.get_group_by_index(gi)
		#if !g or !is_instance_valid(g):
			#continue
		#for f: Fighter in g.get_combatants(false):
			#if f and is_instance_valid(f):
				#f.set_pending_turn_glow(Fighter.TurnStatus.NONE)
#
#func _on_pending_view_changed(active_id: int, pending_ids: PackedInt32Array) -> void:
	###print("battle.gd _on_pending_view_changed()")
	#_apply_glow_live(active_id, pending_ids)
#
#func _on_actor_requested(combat_id: int) -> void:
	## HARD RULE: don’t start an actor while arcana still running.
	#await _await_arcana_gate_if_any()
	#
	##sim_host.debug_dump_orders()
	##sim_host.debug_dump_units()
	##debug_dump_orders_live()
	##debug_dump_units_live()
#
	#if host.is_player(combat_id):
		#wait_for_anims = false
		#_arm_end_turn_button(true)
#
	#var ok := await _run_actor_live(combat_id)
	#if ok:
		#turn_engine.notify_actor_done(combat_id)
#
#func _run_actor_live(combat_id:int) -> bool:
	##print("battle.gd _run_actor_live() step 1")
	#var f: Fighter = battle_scene.get_combatant_by_id(combat_id, true)
	#if !f or !is_instance_valid(f) or !f.is_alive():
		#turn_engine.notify_actor_removed(combat_id)
		#return false
	#
	#var runner := api.runner
	#var scope_id := runner.begin_scope(combat_id) if runner else 0
	#f.turn_scope_id = scope_id
	#
	## Start-of-turn
	#f.enter()
	#api.run_status_proc(combat_id, Status.ProcType.START_OF_TURN)
	#await _await_status_proc_finished(f, Status.ProcType.START_OF_TURN)
	##print("battle.gd _run_actor_live() step 2")
	## Main action (NPC retains/releases scope internally once you add that)
	#f.do_turn()
	#await _await_action_or_removal(f)
	##print("battle.gd _run_actor_live() step 3")
	## End-of-turn
	#api.run_status_proc(combat_id, Status.ProcType.END_OF_TURN)
	#await _await_status_proc_finished(f, Status.ProcType.END_OF_TURN)
	##print("battle.gd _run_actor_live() step 4")
	## Now we know the actor is done enqueueing anything *new*
	#if runner and scope_id != 0:
		#runner.close_scope(scope_id)
		#await runner.await_scope_drained(scope_id)
		#runner.end_scope(scope_id)
	##print("battle.gd _run_actor_live() step 5")
	#f.exit()
	#return true
#
#func _await_action_or_removal(actor: Fighter) -> bool:
	#while actor and is_instance_valid(actor):
		##print("battle.gd _await_action_or_removal() awaiting %s, cid: %s..." % [actor.name, actor.combat_id])
		#var resolved: Fighter = await actor.action_resolved
		#if resolved == actor:
			##print("battle.gd _await_action_or_removal() %s, cid: %s action resolved." % [actor.name, actor.combat_id])
			#return true
	#return false
#
#func _on_arcana_proc_requested(proc: int, token: int) -> void:
	##print("battle.gd _on_arcana_proc_requested")
#
	#var arcanum_type := -1
	#match proc:
		#TurnEngineCore.ArcanaProc.START_OF_COMBAT:
			#arcanum_type = Arcanum.Type.START_OF_COMBAT
		#TurnEngineCore.ArcanaProc.START_OF_TURN:
			#arcanum_type = Arcanum.Type.START_OF_TURN
		#TurnEngineCore.ArcanaProc.END_OF_TURN:
			#arcanum_type = Arcanum.Type.END_OF_TURN
		#_:
			#turn_engine.notify_arcana_proc_done(token)
			#return
#
	## start arcana in detached scope, but do NOT await here.
	#_start_arcana_scope_detached(arcanum_type)
#
	## Engine can proceed immediately, but execution paths will await the gate.
	#turn_engine.notify_arcana_proc_done(token)
#
#
#func _run_arcana_start_of_combat(token: int) -> void:
	#arcana.activate_arcana_by_type_async(Arcanum.Type.START_OF_COMBAT, self)
	##await _with_system_scope_async(-1, func():
		##return arcana.activate_arcana_by_type_async(Arcanum.Type.START_OF_COMBAT, self)
	##)
	#turn_engine.notify_arcana_proc_done(token)
#
#func _run_arcana_start_of_turn(token: int) -> void:
	#arcana.activate_arcana_by_type_async(Arcanum.Type.START_OF_TURN, self)
	##await _with_system_scope_async(-1, func():
		##return arcana.activate_arcana_by_type_async(Arcanum.Type.START_OF_TURN, self)
	##)
	#turn_engine.notify_arcana_proc_done(token)
#
#func _run_arcana_end_of_turn(token: int) -> void:
	#arcana.activate_arcana_by_type_async(Arcanum.Type.END_OF_TURN, self)
	##await _with_system_scope_async(-1, func():
		##return arcana.activate_arcana_by_type_async(Arcanum.Type.END_OF_TURN, self)
	##)
	#turn_engine.notify_arcana_proc_done(token)
#
#func _await_arcana_gate_if_any() -> void:
	#if _arcana_gate == null:
		#return
#
	## Wait for whatever we stored (FunctionState or Signal)
	#var g = _arcana_gate
	#if typeof(g) == TYPE_OBJECT and g != null and g.get_class() == "GDScriptFunctionState":
		#await g
	#elif g is Signal and !(g as Signal).is_null():
		#await g
	## else: ignore
#
#func _start_arcana_scope_detached(arcanum_type: int) -> void:
	#if !arcana or !api or !api.runner:
		#arcana.activate_arcana_by_type_async(arcanum_type, self)
		#return
#
	#var runner := api.runner
	#var sid := runner.begin_scope(-1)
#
	## IMPORTANT: enqueue arcana ops while sid is the current scope
	#arcana.activate_arcana_by_type_async(arcanum_type, self)
#
	## Close scope to say “no more new items for this scope”
	#runner.close_scope(sid)
#
	## Detach from stack so other scopes can proceed normally
	#runner.pop_scope(sid)
#
	#_arcana_gate_seq += 1
	#var my_seq := _arcana_gate_seq
#
	## Store the awaitable (FunctionState), DO NOT await it here
	#_arcana_gate = await runner.await_scope_drained(sid)
#
	## fire-and-forget cleanup
	#_finish_detached_scope_later(sid, my_seq)
#
##func _start_arcana_scope_detached(arcanum_type: int) -> void:
	##if !arcana or !api or !api.runner:
		##arcana.activate_arcana_by_type_async(arcanum_type, self)
		##return
##
	##var runner := api.runner
	##var sid := runner.begin_scope(-1)
##
	##arcana.activate_arcana_by_type_async(arcanum_type, self)
##
	##runner.close_scope(sid)
	##runner.pop_scope(sid)
##
	##_arcana_gate_seq += 1
	##var my_seq := _arcana_gate_seq
##
	### Set the gate to something awaitable
	##_arcana_gate = await runner.await_scope_drained(sid)
##
	### fire-and-forget cleanup
	##_finish_detached_scope_later(sid, my_seq)
#
#func begin_player_turn_async() -> bool:
	##print("battle.gd begin_player_turn_async()")
	#await _await_arcana_gate_if_any()
#
	#wait_for_anims = true
	#_arm_end_turn_button(false)
#
	#if player and is_instance_valid(player):
		#player.combatant_data.reset_armor()
		#player.combatant_data.reset_mana()
		#_on_player_data_changed()
#
	#_prepare_hand_draw_gate()
	#Events.request_draw_hand.emit()
	#await _await_hand_draw_gate()
#
	##print("battle.gd begin_player_turn_async() done awaiting hand_draw")
	#wait_for_anims = false
	#
	##sim_host.debug_dump_orders()
	##sim_host.debug_dump_units()
	##debug_dump_orders_live()
	##debug_dump_units_live()
	#
	#return true
#
#func _prepare_hand_draw_gate() -> void:
	#_wait_hand_drawn_done = false
	#var c := Callable(self, "_on_hand_drawn_one_shot")
	#if Events.hand_drawn.is_connected(c):
		#Events.hand_drawn.disconnect(c)
	#Events.hand_drawn.connect(c, CONNECT_ONE_SHOT)
#
#func _await_hand_draw_gate() -> void:
	#while !_wait_hand_drawn_done:
		#await get_tree().process_frame
#
##func end_player_turn_async() -> bool:
	###print("battle.gd end_player_turn_async()")
	### Called by TurnEngineCore after it thinks player is "done".
	### Goal: ensure discard finished, resolve action, and drain runner scope (already handled in _run_actor_live)
##
	##await _await_arcana_gate_if_any()
##
	### If End Turn triggers discard flow, wait for that to complete.
	### We treat hand_discarded as the boundary that the player's chosen discard is complete.
	##await _await_hand_discarded_once()
##
	### Now resolve the player's action (this is what PlayerBehavior used to do)
	##if player and is_instance_valid(player):
		##player.resolve_action()
	##return true
#
#var _wait_hand_discarded_done: bool = false
#
#
#
#
	#
	#
	#
##func _await_hand_discarded_once() -> void:
	###print("battle.gd _await_hand_discarded_once()")
	##_wait_hand_discarded_done = false
	##if !Events.hand_discarded.is_connected(_on_hand_discarded_one_shot):
		##Events.hand_discarded.connect(_on_hand_discarded_one_shot, CONNECT_ONE_SHOT)
	##while !_wait_hand_discarded_done:
		##await get_tree().process_frame
#
#var _wait_hand_drawn_done: bool = false
#func _on_hand_drawn_one_shot() -> void:
	##print("battle.gd _on_hand_drawn_one_shot()")
	#_wait_hand_drawn_done = true
#func _await_hand_drawn_once() -> void:
	##print("battle.gd _await_hand_drawn_once()")
	#_wait_hand_drawn_done = false
	#if !Events.hand_drawn.is_connected(_on_hand_drawn_one_shot):
		#Events.hand_drawn.connect(_on_hand_drawn_one_shot, CONNECT_ONE_SHOT)
	#while !_wait_hand_drawn_done:
		#await get_tree().process_frame
#
#func _finish_detached_scope_later(scope_id: int, seq: int) -> bool:
	## This is the gate "promise"
	#await api.runner.await_scope_drained(scope_id)
	#api.runner.end_scope(scope_id)
#
	## Only clear if we're still the latest gate
	#if seq == _arcana_gate_seq:
		#_arcana_gate = null
	#return true
#
#func _await_status_proc_finished(actor: Fighter, want_proc: Status.ProcType) -> void:
	#var start_tick := actor.last_status_proc_tick
	#if actor.last_status_proc_finished == want_proc and actor.last_status_proc_tick != start_tick:
		#return
	#
	#while actor and is_instance_valid(actor):
		#var got: int = await actor.status_proc_finished
		#if got == want_proc:
			#return
#
#func _on_group_turn_ended(ended_group_index: int) -> void:
	#await _await_arcana_gate_if_any()
	#_apply_group_turn_end_hooks(ended_group_index)
#
	#if ended_group_index == 0:
		#Events.enemy_turn_started.emit()
		#await _apply_group_turn_start_hooks_scoped(1)
		#_arm_end_turn_button(false)
		#turn_engine.start_group_turn(1, false)
		#return
#
	#Events.friendly_turn_started.emit()
	#await _apply_group_turn_start_hooks_scoped(0)
	#_arm_end_turn_button(false)
	#turn_engine.start_group_turn(0, false)
#
#func _get_next_group_index(ended_group_index: int) -> int:
	#match ended_group_index:
		#0:
			#return 1
		#1:
			#return 0
		#_:
			#return -1
#
#func _apply_group_turn_start_hooks_scoped(active_group_index: int) -> void:
	##print("battle.gd _apply_group_turn_start_hooks_scoped() active_group_index: ", active_group_index)
	#await _with_system_scope_async(-1, func():
		#_apply_group_turn_start_hooks(active_group_index)
	#)
#
#func _apply_group_turn_start_hooks(active_group_index: int) -> void:
	##print("battle.gd _apply_group_turn_start_hooks() active_group_index: ", active_group_index)
	## Group starting: members get my_group_turn_start; opposing gets opposing_group_turn_start
	#var my_group: BattleGroup = battle_scene.get_group_by_index(active_group_index)
	#if !my_group or !is_instance_valid(my_group):
		#return
	#
	#var opp_group: BattleGroup = battle_scene.get_group_by_index(_get_next_group_index(active_group_index))
	#if !opp_group or !is_instance_valid(opp_group):
		#opp_group = null
	#
	#for f: Fighter in my_group.get_combatants(false):
		#if f and is_instance_valid(f):
			#f.my_group_turn_start()
	#
	#if opp_group:
		#for f: Fighter in opp_group.get_combatants(false):
			#if f and is_instance_valid(f):
				#f.opposing_group_turn_start()
	#
	## Optional: do any Battle-level start-of-turn plumbing here
	## - reset per-group UI
	## - clear intent previews
	## - arcana “start of friendly/enemy group turn” proc hooks, etc.
#
#func _apply_group_turn_end_hooks(ended_group_index: int) -> void:
	## Group ending: members get my_group_turn_end; opposing gets opposing_group_turn_end
	#var my_group: BattleGroup = battle_scene.get_group_by_index(ended_group_index)
	#if !my_group or !is_instance_valid(my_group):
		#return
	#
	#var opp_group: BattleGroup = battle_scene.get_group_by_index(_get_next_group_index(ended_group_index))
	#if !opp_group or !is_instance_valid(opp_group):
		#opp_group = null
	#
	#for f: Fighter in my_group.get_combatants(false):
		#if f and is_instance_valid(f):
			#f.my_group_turn_end()
	#
	#if opp_group:
		#for f: Fighter in opp_group.get_combatants(false):
			#if f and is_instance_valid(f):
				#f.opposing_group_turn_end()
	#
	## Optional: do any Battle-level end-of-turn plumbing here
	## - discard hand / cleanup UI
	## - arcana “end of friendly/enemy group turn” proc hooks, etc.
#
#func _with_system_scope(actor_id: int, work: Callable) -> void:
	#var runner := api.runner
	#if !runner:
		#work.call()
		#return
	#
	#var sid := runner.begin_scope(actor_id) # actor_id can be -1 or "group leader" id
	##print("battle.gd _with_system_scope() actor_id: %s, sid: %s calling work and awaiting..." % [actor_id, sid])
	#work.call()
	#runner.close_scope(sid)
	#await runner.await_scope_drained(sid)
	##print("battle.gd _with_system_scope() actor_id: %s, sid: %s done awaiting." % [actor_id, sid])
	#runner.end_scope(sid)
#
#func _with_system_scope_async(actor_id: int, work: Callable) -> void:
	#var runner := api.runner
#
	#if !runner:
		#var r = work.call()
		#if typeof(r) == TYPE_OBJECT and r != null and r.get_class() == "GDScriptFunctionState":
			#await r
		#elif r is Signal:
			#await r
		#return
#
	#var sid := runner.begin_scope(actor_id)
	##print("battle.gd _with_system_scope_async() actor_id: %s, sid: %s calling work and awaiting..." % [actor_id, sid])
#
	#var result = work.call()
#
	## If work kicked off an async function, keep the scope open until it completes.
	#if typeof(result) == TYPE_OBJECT and result != null and result.get_class() == "GDScriptFunctionState":
		##print("battle.gd _with_system_scope_async() actor_id: %s, sid: %s now awaiting (a)..." % [actor_id, sid])
		#await result
	#elif result is Signal and !(result as Signal).is_null():
		##print("battle.gd _with_system_scope_async() actor_id: %s, sid: %s now awaiting (b)..." % [actor_id, sid])
		#await result
#
	## Now we know the async work is done enqueueing anything new
	#runner.close_scope(sid)
	#await runner.await_scope_drained(sid)
	##print("battle.gd _with_system_scope_async() actor_id: %s, sid: %s done awaiting." % [actor_id, sid])
	#runner.end_scope(sid)
#
#func make_player_combatant() -> void:
	##var new_player: Player = player_scn.instantiate()
	##battle_scene.add_combatant(new_player, 0, 0)
	##new_player.combatant_data = player_data
	#player_data.alive = true
	##battle_scene.set_player(new_player)
	##player = new_player
	#hand.player_data = player_data
	#sim_host.add_combatant_from_data(player_data, 0, 0, true)
#
#func make_enemies() -> void:
	#if !battle_data:
		#thank_you_box.show()
		#return
	#for enemy_data: CombatantData in battle_data.enemies:
		##var new_enemy: Enemy = enemy_scn.instantiate()
		##var new_enemy_index: int = battle_scene.get_n_combatants_in_group(1)
		##battle_scene.add_combatant(new_enemy, 1, new_enemy_index)
		#var new_data: CombatantData = enemy_data.duplicate()
		#new_data.init()
		##new_enemy.combatant_data = new_data
		#sim_host.add_combatant_from_data(new_data, 1, -1, false)
#
#func _on_end_turn_pressed() -> void:
	#if wait_for_anims:
		#return
	#Events.end_turn_button_pressed.emit()
#
#func _on_player_data_changed() -> void:
	#if player:
		#mana_panel.mana = player.combatant_data.mana
#
#func _on_hand_drawn() -> void:
	##print_tree_pretty()
	##run._print_tree()
	#pass
	##_arm_end_turn_button(true)
	##wait_for_anims = false
#
#func _on_dead_combatant_data(combatant_data: CombatantData):
	#if combatant_data == player.combatant_data:
		#Events.request_defeat.emit()
		##BattleController.transition(BattleController.BattleState.GAME_OVER)
#
#func _on_battle_group_empty(_battle_group: BattleGroup) -> void:
	#if _battle_group is BattleGroupEnemy:
		#await _with_system_scope_async(-1, func():
			#return arcana.activate_arcana_by_type_async(Arcanum.Type.END_OF_COMBAT, self)
		#)
		##BattleController.transition(BattleController.BattleState.VICTORY)
#
#func _on_summon_reserve_card_released(summoned_ally: SummonedAlly) -> void:
	#var perspective_card: PerspectiveCard = perspective_card_scn.instantiate()
	#battle_ui.add_child(perspective_card)
	#perspective_card.zoom_card(summoned_ally.global_position + Vector2(0, -summoned_ally.combatant_data.height/2.0), discard_pile_button.global_position)
#
#func _on_request_defeat():
	#Events.battle_over_screen_requested.emit("YOU DIED", BattleOverPanel.Outcome.LOSE)
#
#func _on_request_victory():
	#Events.battle_over_screen_requested.emit("PATH CLEARED", BattleOverPanel.Outcome.WIN)
#
#func _on_kill_enemies_button_pressed() -> void:
	#battle_scene.kill_enemies()
#
#func _on_pre_game_ended() -> void:
	#pass
#
#func on_modifier_tokens_changed(mod_type: Modifier.Type) -> void:
	#battle_scene._on_modifier_tokens_changed(mod_type)
#
#func _try_start_turn_order_spark() -> void:
	#if !_spark:
		#return
	#
	#var path := battle_scene.build_turn_order_path()
	#if !path or !path.is_valid():
		#return
	#
	#_spark.play(path)
#
#func _on_fighter_entered_turn(fighter: Fighter) -> void:
	#turn_phase_title.update_turn_text(fighter)
#
#func _cancel_turn_order_spark() -> void:
	#if _spark and _spark.is_active():
		#_spark.cancel()
#
#func _enable_preview_turn_flow_button() -> void:
	#turn_phase_title.enable_button(true)
#
#func _disable_preview_turn_flow_button() -> void:
	#turn_phase_title.enable_button(false)
#
#func _on_request_hand_draw() -> void:
	#wait_for_anims = true
	#_arm_end_turn_button(false)
	##Events.request_draw_hand.emit()
#
#
#func simulate_battle() -> void:
	#pass
	##var sim_battle := SimBattle.from_battle_scene(battle_scene, run.status_catalog)
	##sim_battle.print_sim_snapshot()
#
#func _on_hand_done_drawing() -> void:
	##above^:     Events.hand_drawn.connect(_on_hand_done_drawing)
	##print("battle.gd _on_hand_done_drawing()")
	#await _await_arcana_gate_if_any()
	#wait_for_anims = false
	#
#
#func _arm_end_turn_button(armed: bool) -> void:
	##print("battle.gd _arm_end_turn_button() armed: ", armed)
	#_player_end_turn_armed = armed
	#battle_ui.set_end_turn_enabled(armed)
#
#
#func debug_dump_orders_live() -> void:
	#if battle_scene == null or !is_instance_valid(battle_scene):
		#push_warning("Battle.debug_dump_orders_live(): (no battle_scene)")
		#return
#
	#var friendly := _get_live_group_order_ids(FRIENDLY)
	#var enemy := _get_live_group_order_ids(ENEMY)
#
	#print("Battle LIVE orders:")
	#print("\tFRIENDLY: ", Array(friendly))
	#print("\tENEMY:    ", Array(enemy))
#
#
#func debug_dump_units_live() -> void:
	#if battle_scene == null or !is_instance_valid(battle_scene):
		#print("Battle.debug_dump_units_live(): (no battle_scene)")
		#return
#
	#print("Battle LIVE units dump:")
	#for group_index in [FRIENDLY, ENEMY]:
		#var gname := "FRIENDLY" if group_index == FRIENDLY else "ENEMY"
		#var fighters := _get_live_group_fighters(group_index)
#
		#var order: Array[int] = []
		#order.resize(fighters.size())
		#for i in range(fighters.size()):
			#var f: Fighter = fighters[i]
			#order[i] = int(f.combat_id) if f != null else 0
#
		#print("%s order: %s" % [gname, order])
#
		#for i in range(fighters.size()):
			#var f: Fighter = fighters[i]
			#if f == null or !is_instance_valid(f):
				#print("\t[%d] cid=%d MISSING_UNIT" % [i, int(order[i])])
				#continue
#
			#var cid := int(f.combat_id)
			#var uname := _debug_live_unit_name(f)
#
			#var hp := -1
			#var max_hp := -1
			#var alive := false
#
			#if f.combatant_data != null:
				#if "health" in f.combatant_data:
					#hp = int(f.combatant_data.health)
				#elif "hp" in f.combatant_data:
					#hp = int(f.combatant_data.hp)
#
				#if "max_health" in f.combatant_data:
					#max_hp = int(f.combatant_data.max_health)
				#elif "max_hp" in f.combatant_data:
					#max_hp = int(f.combatant_data.max_hp)
#
				#alive = f.combatant_data.is_alive() if f.combatant_data.has_method("is_alive") else f.is_alive()
			#else:
				#alive = f.is_alive()
#
			#var hp_str := "%d/%d" % [hp, max_hp] if hp >= 0 and max_hp >= 0 else ("%d" % hp if hp >= 0 else "?")
#
			#var statuses_str := _format_live_statuses(f)
#
			#print("\t[%d] cid=%d name=%s hp=%s group=%s pos=%d alive=%s%s" % [
				#i, cid, uname, hp_str, gname, i, str(alive), statuses_str
			#])
#
#
## -------------------------
## Internal helpers (LIVE)
## -------------------------
#
#func _get_live_group_fighters(group_index: int) -> Array:
	#if battle_scene == null or !is_instance_valid(battle_scene):
		#return []
	#var g: BattleGroup = battle_scene.get_group_by_index(group_index)
	#if g == null:
		#return []
	## `false` here should match your TurnEngineHostLive: "get_combatants(false)"
	#return g.get_combatants(false)
#
#
#func _get_live_group_order_ids(group_index: int) -> PackedInt32Array:
	#var out := PackedInt32Array()
	#var fighters := _get_live_group_fighters(group_index)
	#for f: Fighter in fighters:
		#if f != null and is_instance_valid(f):
			#out.append(int(f.combat_id))
	#return out
#
#
#func _debug_live_unit_name(f: Fighter) -> String:
	## 1) Fighter name (your logs show this is good)
	#if f != null:
		#var n := String(f.name)
		#if n != "":
			#return n
#
	## 2) Try CombatantData name-ish fields if present
	#if f != null and f.combatant_data != null:
		#if "display_name" in f.combatant_data:
			#var dn := String(f.combatant_data.display_name)
			#if dn != "":
				#return dn
		#if "combatant_name" in f.combatant_data:
			#var cn := String(f.combatant_data.combatant_name)
			#if cn != "":
				#return cn
#
	## 3) proto path basename if available
	#if f != null and f.combatant_data != null and ("resource_path" in f.combatant_data):
		#var p := String(f.combatant_data.resource_path)
		#if p != "":
			#var base := p.get_file()
			#if base != "":
				#return base.get_basename()
#
	#return "<unnamed>"
#
#func _format_live_statuses(f: Fighter) -> String:
	#if f == null or !is_instance_valid(f):
		#return ""
#
	## Try common field names
	#var ss = null
	#if "status_system" in f:
		#ss = f.status_system
	#elif f.has_method("get_status_system"):
		#ss = f.get_status_system()
#
	#if ss == null:
		#return ""
#
	#if !ss.has_method("get_all"):
		#return ""
#
	#var statuses: Array = ss.get_all()
	#if statuses == null or statuses.is_empty():
		#return ""
#
	#var parts: Array[String] = []
	#for s in statuses:
		#if s == null:
			#continue
#
		## id
		#var sid := ""
		#if s.has_method("get_id"):
			#sid = String(s.get_id())
		#elif "id" in s:
			#sid = String(s.id)
		#if sid == "":
			#sid = "<status>"
#
		## Prefer display policy if present
		#var show := ""
		#var dur := 0
		#var inten := 0
#
		#if "duration" in s:
			#dur = int(s.duration)
		#if "intensity" in s:
			#inten = int(s.intensity)
#
		## number_display_type is your authoring knob (Duration vs Intensity etc.)
		#var ndt := -1
		#if "number_display_type" in s:
			#ndt = int(s.number_display_type)
#
		## Your Status enum likely: NumberDisplayType.DURATION / INTENSITY
		## But we can’t rely on the enum values here, so we do heuristic:
		## - if intensity > 0 and duration == 0 => show intensity
		## - if duration > 0 and intensity == 0 => show duration
		## - if both > 0 => show both
		## - if both == 0 => just id
#
		#if dur > 0 and inten > 0:
			#show = "dur=%d int=%d" % [dur, inten]
		#elif dur > 0:
			#show = "dur=%d" % dur
		#elif inten > 0:
			#show = "int=%d" % inten
		#else:
			#show = ""
#
		## If number_display_type exists, use it to pick which one to show
		## (still keep fallback if the chosen value is 0)
		#if ndt != -1:
			## Best-effort: compare enum key names if available
			#if s.get_script() and s.get_script().has_script_signal("dummy_nope"):
				#pass # no-op, just avoiding unused warning patterns
			## We can’t read enum names reliably; keep it heuristic:
			## If ndt is set and one of dur/int is nonzero, prefer the nonzero one.
			#if dur > 0 and inten == 0:
				#show = "dur=%d" % dur
			#elif inten > 0 and dur == 0:
				#show = "int=%d" % inten
			## else leave "both" as-is
#
		#if show != "":
			#parts.append("%s(%s)" % [sid, show])
		#else:
			#parts.append("%s" % sid)
#
	#return " [" + ", ".join(parts) + "]"
#
#func _on_player_begin_requested(token: int) -> void:
	#var ok := await begin_player_turn_async()
	#turn_engine.notify_player_begin_done(token)
#
##func _on_player_end_requested(token: int) -> void:
	### TurnEngine is asking Battle to actually complete the player turn.
	### This should:
	### - wait for discard flow to finish
	### - call player.resolve_action()
	### - then notify engine so it can continue (arcana / next actor)
	##var ok := await end_player_turn_async()
	##turn_engine.notify_player_end_done(token)
#
#
#func _on_dump_states_button_pressed() -> void:
	#sim_host.debug_dump_orders()
	#sim_host.debug_dump_units()
	#debug_dump_orders_live()
	#debug_dump_units_live()
#
#
#func _on_dump_events_button_pressed() -> void:
	#sim_host.debug_dump_events()
