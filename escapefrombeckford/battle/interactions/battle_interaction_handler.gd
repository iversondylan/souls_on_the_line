# battle_interaction_handler.gd
class_name BattleInteractionHandler
extends Node

enum Mode { NORMAL, SUMMON_REPLACE, SWAP_PARTNER, DISCARD }

var mode: int = Mode.NORMAL
var active: InteractionContext = null

var battle: Battle
var hand: Hand
var battle_ui: BattleUI
var prompt: SelectionPrompt

func _ready() -> void:
	Events.request_summon_replace.connect(on_request_summon_replace)
	Events.request_swap_partner.connect(on_request_swap_partner)
	Events.request_discard_cards.connect(on_request_discard_cards)

	Events.combatant_view_clicked.connect(on_combatant_view_clicked)
	Events.combatant_view_hovered.connect(on_combatant_view_hovered)
	Events.combatant_view_unhovered.connect(on_combatant_view_unhovered)
	Events.selection_prompt_button_pressed.connect(on_prompt_button_pressed)

func setup(_battle: Battle) -> void:
	battle = _battle
	hand = battle.hand
	battle_ui = battle.battle_ui
	prompt = battle.selection_prompt

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

func lock_for_modal() -> void:
	battle.wait_for_anims = true
	hand.set_modal_selecting(true)
	hand.disable_hand_cards()
	battle_ui.set_end_turn_enabled(false)

func unlock_from_modal() -> void:
	battle.wait_for_anims = false
	battle_ui.set_end_turn_enabled(true)
	hand.enable_hand_cards()
	hand.set_modal_selecting(false)

func prompt_show(text: String, button_text: String) -> void:
	prompt.show_prompt(text, button_text)

func prompt_hide() -> void:
	prompt.hide_prompt()

func prompt_set_enabled(on: bool) -> void:
	prompt.set_button_enabled(on)

func make_summon_ghost(preview: SummonPreview) -> Node2D:
	var ghost := Node2D.new()
	var spr := Sprite2D.new()
	ghost.add_child(spr)

	if preview == null or preview.summon_data == null:
		return ghost

	var texture := preview.summon_data.load_character_art()
	if texture == null:
		return ghost
	spr.texture = texture

	var color := preview.summon_data.color_tint
	color.a = 0.55
	spr.modulate = color

	var scalar: float = float(preview.summon_data.height) / float(spr.texture.get_height())
	spr.scale = Vector2(scalar, scalar)
	spr.position = Vector2(0, -preview.summon_data.height / 2.0)

	ghost.z_index = 5
	return ghost

func on_request_discard_cards(ctx: DiscardContext) -> void:
	if mode != Mode.NORMAL:
		return
	if ctx == null:
		return

	var c := DiscardInteractionContext.new()
	c.discard_ctx = ctx
	begin(c, Mode.DISCARD)

func on_request_summon_replace(ctx: CardContext, action_index: int, preview: SummonPreview) -> void:
	if mode != Mode.NORMAL:
		return
	if ctx == null:
		return

	var c := SummonReplaceInteractionContext.new()
	c.card_ctx = ctx
	c.action_index = action_index
	c.preview = preview
	begin(c, Mode.SUMMON_REPLACE)

func on_request_swap_partner(ctx: CardContext, action_index: int) -> void:
	if mode != Mode.NORMAL:
		return
	if ctx == null:
		return
	if battle == null or battle.battle_view == null:
		return

	var c := SwapPartnerInteractionContext.new()
	c.card_ctx = ctx
	c.action_index = action_index
	begin(c, Mode.SWAP_PARTNER)

func on_combatant_view_hovered(v: CombatantView) -> void:
	if active == null:
		return
	if active.has_method("on_hover"):
		active.on_hover(v)

func on_combatant_view_unhovered(v: CombatantView) -> void:
	if active == null:
		return
	if active.has_method("on_unhover"):
		active.on_unhover(v)

func on_combatant_view_clicked(v: CombatantView) -> void:
	if active == null:
		return
	if active.has_method("on_click"):
		active.on_click(v)

func on_prompt_button_pressed() -> void:
	if active == null:
		return

	active.on_primary()
