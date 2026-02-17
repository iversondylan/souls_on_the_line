# battle.gd

class_name Battle extends Node2D

@export var debug_mode: bool = true:
	set(value):
		if !is_node_ready():
			await ready
		debug_mode = value
		$Debug_UI.visible = debug_mode
@export var music: AudioStream
@export var battle_data: BattleData
@export var arcana: ArcanaSystem

@export var idle_delay_sec: float = 1.0
@export var idle_cooldown_sec: float = 6.0

@onready var player_scn: PackedScene = preload("res://scenes/turn_takers/player.tscn")
@onready var enemy_scn: PackedScene = preload("res://scenes/turn_takers/enemy.tscn")
@onready var perspective_card_scn: PackedScene = preload("res://scenes/perspective_card.tscn")

@onready var draw_view_overlay: CardsViewWindow = $Visual_Overlays/DrawViewWindow
@onready var discard_view_overlay: CardsViewWindow = $Visual_Overlays/DiscardViewWindow
@onready var collection_view_overlay: CardsViewWindow = $Visual_Overlays/CollectionViewWindow
@onready var battle_scene: BattleScene = $Battle_Scene
@onready var mana_panel: ManaPanel = $Battle_UI/ManaPanel
@onready var selection_prompt: SelectionPrompt = $Battle_UI/SelectionPrompt
@onready var battle_interaction_handler: BattleInteractionHandler = $BattleInteractionHandler

@onready var hand = $Battle_UI/Hand
@onready var battle_ui: BattleUI = $Battle_UI

@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton

@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView
@onready var _spark: TurnOrderSparkController = $Battle_UI/TurnOrderSparkController
@onready var turn_phase_title: TurnPhaseTitle = $Battle_UI/TurnPhaseTitle

@onready var thank_you_box: Node2D = $Battle_UI/ThankYouBox

var player_data: PlayerData
var player: Player
var deck: Deck : set = _set_deck
var run: Run : set = _set_run

var mouse_pressed: bool = false
var enemy_character_state: int = 0
var wait_for_anims: bool = false

var run_seed: int
var battle_seed: int

var api: LiveBattleAPI
var host : TurnEngineHostLive
var turn_engine : TurnEngineCore

var _pending_start_engine_group: int = -1
var _pending_start_engine_start_at_player: bool = false
var _player_end_turn_armed: bool = false

func _ready() -> void:
	#print_tree_pretty()
	api = LiveBattleAPI.new(battle_scene)
	host = TurnEngineHostLive.new(battle_scene)
	turn_engine = TurnEngineCore.new(host)
	api.turn_engine = turn_engine
	battle_scene.api = api
	turn_engine.actor_requested.connect(_on_actor_requested)
	turn_engine.group_turn_ended.connect(_on_group_turn_ended)
	turn_engine.pending_view_changed.connect(_on_pending_view_changed)
	Events.live_battle_api_created.emit(api)
	set_process(true)
	
	
	Events.hand_drawn.connect(_enable_preview_turn_flow_button) 
	Events.player_turn_completed.connect(_cancel_turn_order_spark)
	Events.player_turn_completed.connect(_disable_preview_turn_flow_button)
	#Events.player_turn_completed.connect(_on_player_turn_completed)
	Events.end_turn_button_pressed.connect(_cancel_turn_order_spark)
	Events.end_turn_button_pressed.connect(_disable_preview_turn_flow_button)
	turn_phase_title.preview_button_pressed.connect(_try_start_turn_order_spark)
	Events.fighter_entered_turn.connect(_on_fighter_entered_turn)
	
	get_tree().paused = false
	BattleController.current_state = BattleController.BattleState.PRE_GAME
	Events.dead_combatant_data.connect(_on_dead_combatant_data)
	Events.battle_group_empty.connect(_on_battle_group_empty)
	Events.player_combatant_data_changed.connect(_on_player_data_changed)
	Events.hand_drawn.connect(_on_hand_drawn)
	
	# Temporary v
	Events.hand_drawn.connect(simulate_battle)
	# Temporary ^
	
	Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)
	Events.request_defeat.connect(_on_request_defeat)
	Events.request_victory.connect(_on_request_victory)
	Events.request_activate_arcana_by_type.connect(_on_request_activate_arcana_by_type)
	#Events.request_enemy_turn.connect(_on_request_enemy_turn)
	#Events.request_friendly_turn.connect(_on_request_friendly_turn)
	Events.arcana_activated.connect(_on_arcana_activated)
	#Events.request_draw_hand.connect(_on_request_hand_draw)
	
	draw_pile_button.pressed.connect(draw_pile_view.show_current_draw_view.bind("Draw Pile", true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_discard_view.bind("Discard Pile"))
	
	hand.battle_scene = battle_scene
	battle_interaction_handler.setup(self)
	
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed_live)
	Events.hand_drawn.connect(_on_hand_done_drawing)
	# Optional: start with End Turn disabled until we draw
	battle_ui.set_end_turn_enabled(false)

func _set_run(new_run: Run) -> void:
	run = new_run
	api.status_catalog = run.status_catalog
	if !is_node_ready():
		await ready
	battle_scene.run = run

func _set_deck(_deck: Deck) -> void:
	deck = _deck
	hand.deck = deck
	battle_scene.deck = deck

func initialize_card_pile_ui() -> void:
	draw_pile_button.card_pile = deck.draw_pile
	
	draw_pile_view.card_pile = deck.draw_pile
	draw_pile_view.deck = deck
	
	discard_pile_button.card_pile = deck.discard_pile
	
	discard_pile_view.card_pile = deck.discard_pile
	discard_pile_view.deck = deck

func start_battle():
	battle_scene.run_seed = run_seed
	battle_scene.battle_seed = battle_seed
	if wait_for_anims:
		return
	BattleController.current_state = BattleController.BattleState.PRE_GAME
	
	wait_for_anims = true
	
	battle_scene.clear_combatants()
	
	make_player_combatant()
	make_enemies()
	Events.battle_reset.emit()
	battle_scene.build_static_modifiers_from_arcana()
	Events.initiate_first_intents.emit()
	_on_player_data_changed()
	hand.empty_hand()
	deck.reset()
	deck.make_draw_pile()
	MusicPlayer.play(music, true)
	initialize_card_pile_ui()
	BattleController.current_state = BattleController.BattleState.FRIENDLY_TURN
	Events.request_activate_arcana_by_type.emit(Arcanum.Type.START_OF_COMBAT)

func _on_request_activate_arcana_by_type(type: Arcanum.Type):
	
	match type:
		Arcanum.Type.START_OF_COMBAT:
			arcana.activate_arcana_by_type(Arcanum.Type.START_OF_COMBAT)
		Arcanum.Type.START_OF_TURN:
			print("battle.gd _on_request_activate_arcana_by_type START_OF_TURN")
			arcana.activate_arcana_by_type(Arcanum.Type.START_OF_TURN)
		Arcanum.Type.END_OF_TURN:
			arcana.activate_arcana_by_type(Arcanum.Type.END_OF_TURN)
		Arcanum.Type.END_OF_COMBAT:
			arcana.activate_arcana_by_type(Arcanum.Type.END_OF_COMBAT)

func _on_arcana_activated(type: Arcanum.Type) -> void:
	match type:
		Arcanum.Type.START_OF_COMBAT:
			BattleController.current_state = BattleController.BattleState.FRIENDLY_TURN
			Events.first_friendly_turn_started.emit()

			battle_scene.friendly_group_turn_start()
			_apply_group_turn_start_hooks(0)

			# Defer engine start until START_OF_TURN arcana resolves + we draw.
			_pending_start_engine_group = 0
			_pending_start_engine_start_at_player = true
			Events.request_activate_arcana_by_type.emit(Arcanum.Type.START_OF_TURN)

		Arcanum.Type.START_OF_TURN:
			#_request_player_hand_draw()
			#_arm_end_turn_button(true)

			# If we were waiting to start the engine, do it now.
			if _pending_start_engine_group != -1:
				var gi := _pending_start_engine_group
				var sap := _pending_start_engine_start_at_player
				_pending_start_engine_group = -1
				turn_engine.start_group_turn(gi, sap)

		Arcanum.Type.END_OF_COMBAT:
			Events.request_victory.emit()

func _apply_glow_live(active_id: int, pending_ids: PackedInt32Array) -> void:
	# If nothing active, clear glow (or keep last — but clearing is safer)
	print("battle.gd _apply_glow_live() active_id: %s, pending_ids: %s" % [active_id, pending_ids])
	if active_id <= 0:
		_clear_all_pending_glow()
		return

	var group_index := host.get_group_index_of(active_id)
	if group_index < 0:
		_clear_all_pending_glow()
		return

	var group: BattleGroup = battle_scene.get_group_by_index(group_index)
	if !group or !is_instance_valid(group):
		_clear_all_pending_glow()
		return

	# Fast membership check
	var pending_set := {}
	for id in pending_ids:
		pending_set[int(id)] = true

	for f: Fighter in group.get_combatants(false):
		if !f or !is_instance_valid(f):
			continue

		var cid := int(f.combat_id)
		if cid == active_id:
			f.set_pending_turn_glow(Fighter.TurnStatus.TURN_ACTIVE)
		elif pending_set.has(cid):
			f.set_pending_turn_glow(Fighter.TurnStatus.TURN_PENDING)
		else:
			f.set_pending_turn_glow(Fighter.TurnStatus.NONE)


func _clear_all_pending_glow() -> void:
	for gi in [0, 1]:
		var g: BattleGroup = battle_scene.get_group_by_index(gi)
		if !g or !is_instance_valid(g):
			continue
		for f: Fighter in g.get_combatants(false):
			if f and is_instance_valid(f):
				f.set_pending_turn_glow(Fighter.TurnStatus.NONE)

func _on_pending_view_changed(active_id: int, pending_ids: PackedInt32Array) -> void:
	print("battle.gd _on_pending_view_changed()")
	_apply_glow_live(active_id, pending_ids)

func _on_actor_requested(combat_id: int) -> void:
	var ok := await _run_actor_live(combat_id)
	if ok:
		turn_engine.notify_actor_done(combat_id)
	# else _run_actor_live already notified removed

func _run_actor_live(combat_id: int) -> bool:
	var f: Fighter = battle_scene.get_combatant_by_id(combat_id, true)
	if !f or !is_instance_valid(f) or !f.is_alive():
		turn_engine.notify_actor_removed(combat_id)
		return false

	# --- Start-of-turn ---
	f.enter()

	api.run_status_proc(combat_id, Status.ProcType.START_OF_TURN)
	await _await_status_proc_finished(f, Status.ProcType.START_OF_TURN)

	# --- Main action ---
	f.do_turn()
	await _await_action_or_removal(f)

	# --- End-of-turn ---
	api.run_status_proc(combat_id, Status.ProcType.END_OF_TURN)
	await _await_status_proc_finished(f, Status.ProcType.END_OF_TURN)

	f.exit()
	return true


func _await_action_or_removal(actor: Fighter) -> bool:
	while actor and is_instance_valid(actor):
		var resolved: Fighter = await actor.action_resolved
		if resolved == actor:
			return true
	return false


func _await_status_proc_finished(actor: Fighter, want_proc: Status.ProcType) -> void:
	var start_tick := actor.last_status_proc_tick
	if actor.last_status_proc_finished == want_proc and actor.last_status_proc_tick != start_tick:
		return

	while actor and is_instance_valid(actor):
		var got: int = await actor.status_proc_finished
		if got == want_proc:
			return

func _on_group_turn_ended(ended_group_index: int) -> void:
	_apply_group_turn_end_hooks(ended_group_index)

	if ended_group_index == 0:
		# Friendly group ended => real END_OF_TURN boundary
		Events.request_activate_arcana_by_type.emit(Arcanum.Type.END_OF_TURN)

		# Friendly -> Enemy
		battle_scene.friendly_group_turn_end()
		BattleController.current_state = BattleController.BattleState.ENEMY_TURN
		battle_scene.enemy_group_turn_start()
		Events.enemy_turn_started.emit()

		var next_group_index := 1
		_apply_group_turn_start_hooks(next_group_index)
		_arm_end_turn_button(false) # player not acting
		turn_engine.start_group_turn(next_group_index, false)
		return

	# Enemy -> Friendly
	battle_scene.enemy_group_turn_end()
	BattleController.current_state = BattleController.BattleState.FRIENDLY_TURN
	battle_scene.friendly_group_turn_start()
	Events.friendly_turn_started.emit()

	var next_group_index := 0
	_apply_group_turn_start_hooks(next_group_index)

	# Defer engine start until arcana START_OF_TURN resolves + hand is drawn.
	_pending_start_engine_group = 0
	_pending_start_engine_start_at_player = true
	Events.request_activate_arcana_by_type.emit(Arcanum.Type.START_OF_TURN)

func _get_next_group_index(ended_group_index: int) -> int:
	match ended_group_index:
		0:
			return 1
		1:
			return 0
		_:
			return -1

func _apply_group_turn_start_hooks(active_group_index: int) -> void:
	# Group starting: members get my_group_turn_start; opposing gets opposing_group_turn_start
	var my_group: BattleGroup = battle_scene.get_group_by_index(active_group_index)
	if !my_group or !is_instance_valid(my_group):
		return

	var opp_group: BattleGroup = battle_scene.get_group_by_index(_get_next_group_index(active_group_index))
	if !opp_group or !is_instance_valid(opp_group):
		opp_group = null

	for f: Fighter in my_group.get_combatants(false):
		if f and is_instance_valid(f):
			f.my_group_turn_start()

	if opp_group:
		for f: Fighter in opp_group.get_combatants(false):
			if f and is_instance_valid(f):
				f.opposing_group_turn_start()

	# Optional: do any Battle-level start-of-turn plumbing here
	# - reset per-group UI
	# - clear intent previews
	# - arcana “start of friendly/enemy group turn” proc hooks, etc.

func _apply_group_turn_end_hooks(ended_group_index: int) -> void:
	# Group ending: members get my_group_turn_end; opposing gets opposing_group_turn_end
	var my_group: BattleGroup = battle_scene.get_group_by_index(ended_group_index)
	if !my_group or !is_instance_valid(my_group):
		return

	var opp_group: BattleGroup = battle_scene.get_group_by_index(_get_next_group_index(ended_group_index))
	if !opp_group or !is_instance_valid(opp_group):
		opp_group = null

	for f: Fighter in my_group.get_combatants(false):
		if f and is_instance_valid(f):
			f.my_group_turn_end()

	if opp_group:
		for f: Fighter in opp_group.get_combatants(false):
			if f and is_instance_valid(f):
				f.opposing_group_turn_end()

	# Optional: do any Battle-level end-of-turn plumbing here
	# - discard hand / cleanup UI
	# - arcana “end of friendly/enemy group turn” proc hooks, etc.

func make_player_combatant() -> void:
	var new_player: Player = player_scn.instantiate()
	battle_scene.add_combatant(new_player, 0, 0)
	new_player.combatant_data = player_data
	player_data.alive = true
	battle_scene.set_player(new_player)
	player = new_player
	hand.player = new_player

func make_enemies() -> void:
	if !battle_data:
		thank_you_box.show()
		return
	for enemy_data: CombatantData in battle_data.enemies:
		var new_enemy: Enemy = enemy_scn.instantiate()
		var new_enemy_index: int = battle_scene.get_n_combatants_in_group(1)
		battle_scene.add_combatant(new_enemy, 1, new_enemy_index)
		var new_data: CombatantData = enemy_data.duplicate()
		new_data.init()
		new_enemy.combatant_data = new_data

func _on_end_turn_pressed() -> void:
	if wait_for_anims:
		return
	Events.end_turn_button_pressed.emit()

func _on_player_data_changed() -> void:
	if player:
		mana_panel.red_mana = player.combatant_data.mana_red
		mana_panel.green_mana = player.combatant_data.mana_green
		mana_panel.blue_mana = player.combatant_data.mana_blue

func _on_hand_drawn() -> void:
	#print_tree_pretty()
	#run._print_tree()
	pass
	#_arm_end_turn_button(true)
	#wait_for_anims = false

func _on_dead_combatant_data(combatant_data: CombatantData):
	if combatant_data == player.combatant_data:
		Events.request_defeat.emit()
		#BattleController.transition(BattleController.BattleState.GAME_OVER)

func _on_battle_group_empty(_battle_group: BattleGroup) -> void:
	if _battle_group is BattleGroupEnemy:
		arcana.activate_arcana_by_type(Arcanum.Type.END_OF_COMBAT)
		#BattleController.transition(BattleController.BattleState.VICTORY)

func _on_summon_reserve_card_released(summoned_ally: SummonedAlly) -> void:
	var perspective_card: PerspectiveCard = perspective_card_scn.instantiate()
	battle_ui.add_child(perspective_card)
	perspective_card.zoom_card(summoned_ally.global_position + Vector2(0, -summoned_ally.combatant_data.height/2.0), discard_pile_button.global_position)

func _on_request_defeat():
	Events.battle_over_screen_requested.emit("YOU DIED", BattleOverPanel.Outcome.LOSE)

func _on_request_victory():
	Events.battle_over_screen_requested.emit("PATH CLEARED", BattleOverPanel.Outcome.WIN)

func _on_kill_enemies_button_pressed() -> void:
	battle_scene.kill_enemies()

func _on_pre_game_ended() -> void:
	pass

func on_modifier_tokens_changed(mod_type: Modifier.Type) -> void:
	battle_scene._on_modifier_tokens_changed(mod_type)

func _try_start_turn_order_spark() -> void:
	if !_spark:
		return
	
	var path := battle_scene.build_turn_order_path()
	if !path or !path.is_valid():
		return
	
	_spark.play(path)

func _on_fighter_entered_turn(fighter: Fighter) -> void:
	turn_phase_title.update_turn_text(fighter)

func _cancel_turn_order_spark() -> void:
	if _spark and _spark.is_active():
		_spark.cancel()

func _enable_preview_turn_flow_button() -> void:
	turn_phase_title.enable_button(true)

func _disable_preview_turn_flow_button() -> void:
	turn_phase_title.enable_button(false)

func _on_request_hand_draw() -> void:
	wait_for_anims = true
	_arm_end_turn_button(false)
	#Events.request_draw_hand.emit()


func simulate_battle() -> void:
	pass
	#var sim_battle := SimBattle.from_battle_scene(battle_scene, run.status_catalog)
	#sim_battle.print_sim_snapshot()

func _on_hand_done_drawing() -> void:
	print("battle.gd _on_hand_done_drawing()")
	wait_for_anims = false
	_arm_end_turn_button(true)


func _arm_end_turn_button(armed: bool) -> void:
	_player_end_turn_armed = armed
	battle_ui.set_end_turn_enabled(armed)

func _on_end_turn_button_pressed_live() -> void:
	if wait_for_anims:
		return
	if BattleController.current_state != BattleController.BattleState.FRIENDLY_TURN:
		return
	if !_player_end_turn_armed:
		return

	# Disarm immediately so double clicks / repeated presses don't re-enter.
	_arm_end_turn_button(false)

	# This is the ONE thing End Turn does:
	# it tells the Player to finish their action, which Hand turns into discard->hand_discarded->resolve_action.
	Events.player_turn_completed.emit()
