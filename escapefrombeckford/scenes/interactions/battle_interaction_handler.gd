# battle_interaction_handler.gd
class_name BattleInteractionHandler
extends Node

enum Mode { NORMAL, SUMMON_REPLACE, SWAP_PARTNER, DISCARD }

var mode: int = Mode.NORMAL
var active: InteractionContext = null

var battle: Battle
var battle_scene: BattleScene
var hand: Hand
var battle_ui: BattleUI
var prompt: SelectionPrompt


func _ready() -> void:
	Events.request_summon_replace.connect(on_request_summon_replace)
	Events.request_swap_partner.connect(on_request_swap_partner)
	Events.request_discard_cards.connect(on_request_discard_cards)

	Events.combatant_target_clicked.connect(on_combatant_target_clicked)
	Events.combatant_target_hovered.connect(on_combatant_target_hovered)
	Events.combatant_target_unhovered.connect(on_combatant_target_unhovered)

	Events.selection_prompt_button_pressed.connect(on_prompt_button_pressed)


func setup(_battle: Battle) -> void:
	battle = _battle
	battle_scene = battle.battle_scene
	hand = battle.hand
	battle_ui = battle.battle_ui
	prompt = battle.selection_prompt


# ------------------------------------------------------------
# Context lifecycle
# ------------------------------------------------------------

func begin(ctx: InteractionContext, new_mode: int) -> void:
	if ctx == null:
		return
	if active != null:
		end_active_context()
	mode = new_mode
	active = ctx
	active.handler = self
	active.enter()

func end_active_context() -> void:
	if active == null:
		return
	active.exit()
	active = null
	mode = Mode.NORMAL
	prompt_hide()


# ------------------------------------------------------------
# Modal locking helpers
# ------------------------------------------------------------

func lock_for_modal() -> void:
	battle.wait_for_anims = true
	hand.disable_hand_cards()
	battle_ui.set_end_turn_enabled(false)


func unlock_from_modal() -> void:
	battle.wait_for_anims = false
	battle_ui.set_end_turn_enabled(true)
	hand.enable_hand_cards()


# ------------------------------------------------------------
# Prompt helpers (single button)
# ------------------------------------------------------------


func prompt_show(text: String, button_text: String) -> void:
	prompt.show_prompt(text, button_text)

func prompt_hide() -> void:
	prompt.hide_prompt()

func prompt_set_enabled(on: bool) -> void:
	prompt.set_button_enabled(on)


# ------------------------------------------------------------
# Reusable visuals helpers
# ------------------------------------------------------------

func make_summon_ghost(effect: SummonEffect) -> Node2D:
	var ghost := Node2D.new()
	var spr := Sprite2D.new()
	ghost.add_child(spr)

	var data: CombatantData = effect.summon_data
	if data == null or data.character_art == null:
		return ghost

	spr.texture = data.character_art

	var color := data.color_tint
	color.a = 0.55
	spr.modulate = color

	var scalar: float = float(data.height) / float(spr.texture.get_height())
	spr.scale = Vector2(scalar, scalar)
	spr.position = Vector2(0, -data.height / 2.0)

	ghost.z_index = 5
	return ghost


func set_candidate_selectable_visuals(a: SummonedAlly, on: bool) -> void:
	if a == null or !is_instance_valid(a):
		return
	a.set_fade_mark(on)


# ------------------------------------------------------------
# Event entry points
# ------------------------------------------------------------

func on_request_summon_replace(card: UsableCard, ctx: CardActionContext, effect: SummonEffect, skip_action: CardAction) -> void:
	if mode != Mode.NORMAL:
		return
	
	var c := SummonReplaceInteractionContext.new()
	c.card = card
	c.card_ctx = ctx
	c.effect = effect
	c.skip_action = skip_action

	begin(c, Mode.SUMMON_REPLACE)


func on_request_discard_cards(ctx: DiscardContext) -> void:
	if mode != Mode.NORMAL:
		return
	if ctx == null:
		return

	# Fill in shared refs here (keeps DiscardEffect generic)
	ctx.battle = battle
	ctx.hand = hand
	ctx.deck = battle.deck

	var c := DiscardInteractionContext.new()
	c.discard_ctx = ctx
	begin(c, Mode.DISCARD)

func on_combatant_target_hovered(f: Fighter) -> void:
	if active == null:
		return
	if active.has_method("on_hover"):
		active.on_hover(f)


func on_combatant_target_unhovered(f: Fighter) -> void:
	if active == null:
		return
	if active.has_method("on_unhover"):
		active.on_unhover(f)


func on_combatant_target_clicked(f: Fighter) -> void:
	if active == null:
		return
	if active.has_method("on_click"):
		active.on_click(f)


func on_prompt_button_pressed() -> void:
	if active == null:
		return

	active.on_primary()

	# DISCARD is async; it will call handler.end_active_context() in _on_discard_done().
	if mode == Mode.DISCARD:
		return

	if active != null:
		end_active_context()




func _cancel_active() -> void:
	print("battle_interaction_handler.gd _cancel_active()")
	if active == null:
		return
	print("...1")
	# Give context a chance to clean up previews, etc.
	if active.has_method("on_cancel"):
		print("...2")
		active.on_primary()
	print("...3")
	# If context didn't end itself, end it here.
	if active != null:
		print("...4")
		end_active_context()

func on_request_swap_partner(card: UsableCard, ctx: CardActionContext, actor: Fighter, skip_action: CardAction) -> void:
	if mode != Mode.NORMAL:
		return

	var c := SwapPartnerInteractionContext.new()
	c.card = card
	c.card_ctx = ctx
	c.actor = actor
	c.skip_action = skip_action

	begin(c, Mode.SWAP_PARTNER)

func set_swap_candidate_visuals(f: Fighter, on: bool) -> void:
	if f == null or !is_instance_valid(f):
		return
	# simplest: reuse targeted arrow or pending glow
	# better: add a dedicated “selectable” mark method on Fighter.
	if on:
		f.set_fade_mark(true) # if Fighter has it; otherwise implement set_selectable_mark on Fighter
	else:
		f.set_fade_mark(false)
