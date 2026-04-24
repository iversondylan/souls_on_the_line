# battle_interaction_handler.gd
class_name BattleInteractionHandler
extends Node

var active: InteractionContext = null

var battle: Battle
var hand: Hand
var battle_ui: BattleUI
var prompt: SelectionPrompt

func _ready() -> void:
	Events.request_interaction.connect(on_request_interaction)

	Events.combatant_view_clicked.connect(on_combatant_view_clicked)
	Events.combatant_view_hovered.connect(on_combatant_view_hovered)
	Events.combatant_view_unhovered.connect(on_combatant_view_unhovered)
	Events.selection_prompt_button_pressed.connect(on_prompt_button_pressed)

func setup(_battle: Battle) -> void:
	battle = _battle
	hand = battle.hand
	battle_ui = battle.battle_ui
	prompt = battle.selection_prompt

func begin(ctx: InteractionContext) -> void:
	if ctx == null:
		return
	if active != null:
		end_active_context()
	active = ctx
	active.handler = self
	active.enter()

func end_active_context() -> void:
	if active == null:
		return
	active.exit()
	active = null
	prompt_hide()

func lock_for_modal() -> void:
	battle.wait_for_anims = true
	hand.set_modal_selecting(true)
	hand.disable_hand_cards()
	battle_ui.set_end_turn_enabled(false)

func unlock_from_modal() -> void:
	battle.wait_for_anims = false
	hand.enable_hand_cards()
	hand.set_modal_selecting(false)
	if battle != null:
		battle.refresh_player_input_visual_state()

func evaluate_interaction_gate(req, card_ctx: CardContext = null, action_index: int = -1) -> bool:
	if battle == null:
		return true
	var result = battle.evaluate_encounter_gate(req)
	if result == null or int(result.verdict) == int(GateResult.Verdict.ALLOW):
		return true
	if card_ctx != null and card_ctx.runtime != null and action_index >= 0:
		card_ctx.runtime.cancel_preflight_interaction(card_ctx, action_index)
	return false

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

func on_request_interaction(ctx: InteractionContext) -> void:
	if active != null:
		return
	if ctx == null:
		return
	ctx.handler = self
	if !ctx.request_open():
		return
	begin(ctx)

func on_combatant_view_hovered(v: CombatantView) -> void:
	if active == null:
		return
	active.on_hover(v)

func on_combatant_view_unhovered(v: CombatantView) -> void:
	if active == null:
		return
	active.on_unhover(v)

func on_combatant_view_clicked(v: CombatantView) -> void:
	if active == null:
		return
	active.on_click(v)

func on_prompt_button_pressed() -> void:
	if active == null:
		return

	active.on_primary()
