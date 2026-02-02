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

@onready var hand = $Battle_UI/Hand
@onready var battle_ui: BattleUI = $Battle_UI

@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton

@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView
@onready var _spark: TurnOrderSparkController = $Battle_UI/TurnOrderSparkController
@onready var turn_phase_title: TurnPhaseTitle = $Battle_UI/TurnPhaseTitle

@onready var thank_you_box: Node2D = $Battle_UI/ThankYouBox


#enum Turn {FRIENDLY_TURN, ENEMY_TURN}
#
#var current_turn := Turn.FRIENDLY_TURN
var player_data: PlayerData
var player: Player
var deck: Deck : set = _set_deck
var run: Run : set = _set_run

var mouse_pressed: bool = false
var enemy_character_state: int = 0
var wait_for_anims: bool = false

enum InteractionMode { NORMAL, SUMMON_REPLACE }
var interaction_mode := InteractionMode.NORMAL

var summon_replace_card: UsableCard
var summon_replace_ctx: CardActionContext
var summon_replace_effect: SummonEffect
var summon_replace_insert_index: int
var summon_replace_ghost: Node2D
var summon_replace_candidates: Array[SummonedAlly] = []
var summon_replace_resolving := false


func _ready() -> void:
	#print_tree_pretty()
	
	set_process(true)
	
	
	Events.hand_drawn.connect(_enable_preview_turn_flow_button) 
	Events.player_turn_completed.connect(_cancel_turn_order_spark)
	Events.player_turn_completed.connect(_disable_preview_turn_flow_button)
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
	Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)
	Events.request_defeat.connect(_on_request_defeat)
	Events.request_victory.connect(_on_request_victory)
	Events.request_activate_arcana_by_type.connect(_on_request_activate_arcana_by_type)
	Events.request_enemy_turn.connect(_on_request_enemy_turn)
	Events.request_friendly_turn.connect(_on_request_friendly_turn)
	Events.arcana_activated.connect(_on_arcana_activated)
	Events.request_draw_cards.connect(_on_request_draw_cards)
	
	
	Events.request_summon_replace.connect(_on_request_summon_replace)

	Events.combatant_target_clicked.connect(_on_combatant_target_clicked)
	Events.combatant_target_hovered.connect(_on_combatant_target_hovered)
	Events.combatant_target_unhovered.connect(_on_combatant_target_unhovered)

	Events.summon_replace_cancel_requested.connect(_on_summon_replace_cancel_requested)

	draw_pile_button.pressed.connect(draw_pile_view.show_current_draw_view.bind("Draw Pile", true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_discard_view.bind("Discard Pile"))
	
	hand.battle_scene = battle_scene

func _set_run(new_run: Run) -> void:
	run = new_run
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
	if wait_for_anims:
		return
	BattleController.current_state = BattleController.BattleState.PRE_GAME
	
	wait_for_anims = true
	
	battle_scene.clear_combatants()
	
	make_player_combatant()
	make_enemies()
	
	Events.battle_reset.emit()
	
	_plan_initial_enemy_intents()
	_on_player_data_changed()
	hand.empty_hand()
	deck.reset()
	deck.make_draw_pile()
	battle_scene.friendly_group_turn_start()
	
	MusicPlayer.play(music, true)
	
	
	Events.request_activate_arcana_by_type.emit(Arcanum.Type.START_OF_COMBAT)

func _plan_initial_enemy_intents() -> void:
	for enemy: Fighter in battle_scene.get_combatants_in_group(1):
		for child in enemy.get_children():
			if child is NPCAIBehavior:
				child.plan_next_intent()
				child.refresh_intent_display()

func _on_request_activate_arcana_by_type(type: Arcanum.Type):
	match type:
		Arcanum.Type.START_OF_COMBAT:
			arcana.activate_arcana_by_type(Arcanum.Type.START_OF_COMBAT)
		Arcanum.Type.START_OF_TURN:
			arcana.activate_arcana_by_type(Arcanum.Type.START_OF_TURN)
		Arcanum.Type.END_OF_TURN:
			#print("battle.gd _on_request_activate_arcana_by_type() END_OF_TURN")
			arcana.activate_arcana_by_type(Arcanum.Type.END_OF_TURN)
		Arcanum.Type.END_OF_COMBAT:
			arcana.activate_arcana_by_type(Arcanum.Type.END_OF_COMBAT)

func _on_request_enemy_turn() -> void:
	battle_scene.friendly_group_turn_end()
	BattleController.current_state = BattleController.BattleState.ENEMY_TURN
	battle_scene.enemy_group_turn_start()
	Events.enemy_turn_started.emit()

func _on_request_friendly_turn() -> void:
	battle_scene.enemy_group_turn_end()
	BattleController.current_state = BattleController.BattleState.FRIENDLY_TURN
	battle_scene.friendly_group_turn_start()
	Events.friendly_turn_started.emit()

func _on_arcana_activated(type: Arcanum.Type) -> void:
	match type:
		Arcanum.Type.START_OF_COMBAT:
			initialize_card_pile_ui()
			BattleController.current_state = BattleController.BattleState.FRIENDLY_TURN
			Events.first_friendly_turn_started.emit()
		Arcanum.Type.END_OF_COMBAT:
			Events.request_victory.emit()
			

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
		#push_error("battle.gd make_enemies() Error: no battle_data")
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
	wait_for_anims = false

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
	#print("main.gd _on_game_over_started()")
	Events.battle_over_screen_requested.emit("YOU DIED", BattleOverPanel.Outcome.LOSE)

func _on_request_victory():
	#print("main.gd _on_victory_started()")
	Events.battle_over_screen_requested.emit("PATH CLEARED", BattleOverPanel.Outcome.WIN)

func _on_kill_enemies_button_pressed() -> void:
	battle_scene.kill_enemies()

func _on_pre_game_ended() -> void:
	pass

func on_modifier_tokens_changed(mod_type: Modifier.Type) -> void:
	battle_scene._on_modifier_tokens_changed(mod_type)

func _lock_for_modal() -> void:
	wait_for_anims = true
	hand.disable_hand_cards()
	battle_ui.set_end_turn_enabled(false) # implement if you don’t have it

func _unlock_from_modal() -> void:
	wait_for_anims = false
	battle_ui.set_end_turn_enabled(true)

func _on_request_summon_replace(card: UsableCard, ctx: CardActionContext, effect: SummonEffect) -> void:
	if interaction_mode != InteractionMode.NORMAL:
		return

	interaction_mode = InteractionMode.SUMMON_REPLACE

	# Store escrow
	summon_replace_card = card
	summon_replace_ctx = ctx
	summon_replace_effect = effect
	summon_replace_insert_index = effect.insert_index

	# Lock battle UI/inputs
	_lock_for_modal_summon_replace()

	# Candidates: summoned allies only
	summon_replace_candidates = []
	for f in battle_scene.get_combatants_in_group(0):
		if f is SummonedAlly and f.is_alive():
			summon_replace_candidates.append(f)

	# Show modal UI
	battle_ui.show_summon_replace_prompt(true) # you implement; includes Cancel button that emits summon_replace_cancel_requested

	# Create + install preview ghost
	summon_replace_ghost = _make_summon_ghost(effect) # see below
	(battle_scene.groups[0] as BattleGroupFriendly).set_preview(summon_replace_ghost, summon_replace_insert_index)

	# Optional: give candidates a “selectable glow” immediately
	for a in summon_replace_candidates:
		_set_candidate_selectable_visuals(a, true)

func _lock_for_modal_summon_replace() -> void:
	wait_for_anims = true
	hand.disable_hand_cards()
	battle_ui.set_end_turn_enabled(false)

func _make_summon_ghost(effect: SummonEffect) -> Node2D:
	var ghost := Node2D.new()
	var spr := Sprite2D.new()
	ghost.add_child(spr)

	var data: CombatantData = effect.summon_data
	if data == null or data.character_art == null:
		return ghost

	spr.texture = data.character_art

	# tint + transparency (match combatant style)
	var color := data.color_tint
	color.a = 0.55
	spr.modulate = color

	# match combatant scaling/offset
	var scalar: float = float(data.height) / float(spr.texture.get_height())
	spr.scale = Vector2(scalar, scalar)
	spr.position = Vector2(0, -data.height / 2.0)

	# optional: ensure it draws on top of background / under fighters
	ghost.z_index = 5

	return ghost

func _set_candidate_selectable_visuals(a: SummonedAlly, on: bool) -> void:
	if on:
		a.set_fade_mark(true)
	else:
		a.set_fade_mark(false)

func _on_combatant_target_hovered(f: Fighter) -> void:
	if interaction_mode != InteractionMode.SUMMON_REPLACE:
		return
	if f is SummonedAlly and summon_replace_candidates.has(f):
		f.show_targeted_arrow()
		# optionally brighten glow, etc.

func _on_combatant_target_unhovered(f: Fighter) -> void:
	if interaction_mode != InteractionMode.SUMMON_REPLACE:
		return
	if f is SummonedAlly and summon_replace_candidates.has(f):
		f.hide_targeted_arrow()

func _on_combatant_target_clicked(f: Fighter) -> void:
	if interaction_mode != InteractionMode.SUMMON_REPLACE:
		return
	if summon_replace_resolving:
		return

	if !(f is SummonedAlly):
		return
	if !summon_replace_candidates.has(f):
		return

	_confirm_summon_replace(f)

func _confirm_summon_replace(chosen: SummonedAlly) -> void:
	summon_replace_resolving = true
	interaction_mode = InteractionMode.SUMMON_REPLACE # already, but you may add a SUBSTATE if needed

	# Turn off candidate clickability visuals now (optional)
	for a in summon_replace_candidates:
		_set_candidate_selectable_visuals(a, false)

	# Start fade animation (you can do it on chosen.character_sprite or whole fighter)
	var tween := create_tween()
	tween.tween_property(chosen.combatant.character_sprite, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func():
		_finish_confirm_after_fade(chosen)
	)

func _finish_confirm_after_fade(chosen: SummonedAlly) -> void:
	# 1) Remove chosen (FADE PATH, not die())
	var friendly := battle_scene.groups[0] as BattleGroupFriendly
	friendly.combatant_faded(chosen) # your step-7 method

	# 2) Remove preview ghost (so layout count stays correct)
	friendly.clear_preview()
	if summon_replace_ghost and is_instance_valid(summon_replace_ghost):
		summon_replace_ghost.queue_free()
	summon_replace_ghost = null

	# 3) Execute the summon
	# IMPORTANT: SummonEffect.execute() already adds the fighter to the group at insert_index
	summon_replace_effect.execute()
	summon_replace_effect.apply_to_card_context(summon_replace_ctx)

	# 4) Commit the card play (spend mana, run other actions, move card)
	_commit_escrow_card_play()

	# 5) Exit modal
	_end_summon_replace_mode()


## SOME OF THE CODE BELOW IS REPEATED FROM usable_card.gd
## WHICH IS STUPID AND I HATE IT ):<
func _commit_escrow_card_play() -> void:
	var card := summon_replace_card
	var ctx := summon_replace_ctx

	# Spend mana now
	ctx.player.spend_mana(ctx.card_data)

	# Execute all actions EXCEPT summon-slot ones (since we already executed effect)
	# It would feel better if these were performed by the usablecard
	# and not in battle.gd
	var any_action := false
	for action: CardAction in ctx.card_data.actions:
		if action.requires_summon_slot():
			continue
		if action.activate(ctx):
			any_action = true

	Events.card_played.emit(card)

	# Destination logic (same as UsableCard.activate)
	if ctx.card_data.deplete:
		card.hand.deplete_card(card.hand.remove_card_by_entity(card))
	elif ctx.card_data.card_type == CardData.CardType.SUMMON:
		card.hand.reserve_summon_card(card.hand.remove_card_by_entity(card))
	else:
		card.hand.discard_card(card.hand.remove_card_by_entity(card))

func _on_summon_replace_cancel_requested() -> void:
	if interaction_mode != InteractionMode.SUMMON_REPLACE:
		return
	_cancel_summon_replace()

func _cancel_summon_replace() -> void:
	summon_replace_resolving = false
	var friendly := battle_scene.groups[0] as BattleGroupFriendly

	friendly.clear_preview()
	if summon_replace_ghost and is_instance_valid(summon_replace_ghost):
		summon_replace_ghost.queue_free()

	for a in summon_replace_candidates:
		_set_candidate_selectable_visuals(a, false)

	_end_summon_replace_mode()

func _end_summon_replace_mode() -> void:
	summon_replace_resolving = false
	battle_ui.show_summon_replace_prompt(false)
	battle_ui.set_end_turn_enabled(true)
	wait_for_anims = false

	# Clear escrow
	summon_replace_card = null
	summon_replace_ctx = null
	summon_replace_effect = null
	summon_replace_candidates.clear()
	summon_replace_ghost = null

	interaction_mode = InteractionMode.NORMAL

	# IMPORTANT: restore pending turn glow after you messed with it
	(battle_scene.groups[0] as BattleGroupFriendly)._update_pending_turn_glow()
	hand.enable_hand_cards()



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

func _on_request_draw_cards(ctx: DrawContext) -> void:
	ctx.hand = hand
	ctx.deck = deck
	wait_for_anims = true
	hand.draw_cards(ctx.amount)
	await hand.done_drawing
	wait_for_anims = false
	Events.cards_drawn.emit(ctx)
