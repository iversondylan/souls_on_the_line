# battle_interaction_handler.gd

class_name BattleInteractionHandler extends Node

enum Mode { NORMAL, SUMMON_REPLACE, SWAP_PARTNER, DISCARD }

var mode := Mode.NORMAL
var active: InteractionContext = null

var battle: Battle
var battle_scene: BattleScene
var hand: Hand
var battle_ui: BattleUI
var wait_for_anims_ref: Callable # optional if you want to flip Battle.wait_for_anims

var prompt : SelectionPrompt#= battle_ui.get_node("SelectionPrompt") # temporary

func _ready() -> void:
	Events.request_summon_replace.connect(on_request_summon_replace)
	#Events.combatant_target_clicked.connect(_on_combatant_target_clicked)
	#Events.combatant_target_hovered.connect(_on_combatant_target_hovered)
	#Events.combatant_target_unhovered.connect(_on_combatant_target_unhovered)
	#Events.selection_prompt_button_pressed.connect(_on_summon_replace_cancel_requested)

func setup(_battle: Battle) -> void:
	battle = _battle
	prompt = _battle.selection_prompt
	battle_scene = battle.battle_scene
	hand = battle.hand
	battle_ui = battle.battle_ui


func begin(ctx: InteractionContext) -> void:
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


func lock_for_modal() -> void:
	battle.wait_for_anims = true
	hand.disable_hand_cards()
	battle_ui.set_end_turn_enabled(false)


func unlock_from_modal() -> void:
	battle.wait_for_anims = false
	battle_ui.set_end_turn_enabled(true)
	hand.enable_hand_cards()


# ---- summon replace helpers reused later ----

func prompt_show_cancel_only(text: String) -> void:
	# adapt to your current SummonReplacePrompt
	battle_ui.show_summon_replace_prompt(true)
	battle_ui.summon_replace_prompt.show_prompt(text)

func prompt_hide() -> void:
	battle_ui.show_summon_replace_prompt(false)

func make_summon_ghost(effect: SummonEffect) -> Node2D:
	# move your existing _make_summon_ghost code here
	# (verbatim)
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
	a.set_fade_mark(on)


# ---- event entry points ----

func on_request_summon_replace(card: UsableCard, ctx: CardActionContext, effect: SummonEffect, skip_action: CardAction) -> void:
	if mode != Mode.NORMAL:
		return
	var c := SummonReplaceInteractionContext.new()
	c.card = card
	c.card_ctx = ctx
	c.effect = effect
	c.skip_action = skip_action
	begin(c)


func on_combatant_target_hovered(f: Fighter) -> void:
	if active and active.has_method("on_hover"):
		active.on_hover(f)

func on_combatant_target_unhovered(f: Fighter) -> void:
	if active and active.has_method("on_unhover"):
		active.on_unhover(f)

func on_combatant_target_clicked(f: Fighter) -> void:
	if active and active.has_method("on_click"):
		active.on_click(f)

func on_cancel_pressed() -> void:
	if active == null:
		return
	# cancel = end context without committing
	prompt_hide()
	end_active_context()


#func _lock_for_modal() -> void:
	#wait_for_anims = true
	#hand.disable_hand_cards()
	#battle_ui.set_end_turn_enabled(false) # implement if you don’t have it
#
#func _unlock_from_modal() -> void:
	#wait_for_anims = false
	#battle_ui.set_end_turn_enabled(true)
#
#func _on_request_summon_replace(card: UsableCard, ctx: CardActionContext, effect: SummonEffect) -> void:
	#if interaction_mode != InteractionMode.NORMAL:
		#return
#
	#interaction_mode = InteractionMode.SUMMON_REPLACE
#
	## Store escrow
	#summon_replace_card = card
	#summon_replace_ctx = ctx
	#summon_replace_effect = effect
	#summon_replace_insert_index = effect.insert_index
#
	## Lock battle UI/inputs
	#_lock_for_modal_summon_replace()
#
	## Candidates: summoned allies only
	#summon_replace_candidates = []
	#for f in battle_scene.get_combatants_in_group(0):
		#if f is SummonedAlly and f.is_alive():
			#summon_replace_candidates.append(f)
#
	## Show modal UI
	#battle_ui.show_summon_replace_prompt(true) # you implement; includes Cancel button that emits summon_replace_cancel_requested
#
	## Create + install preview ghost
	#summon_replace_ghost = _make_summon_ghost(effect) # see below
	#(battle_scene.groups[0] as BattleGroupFriendly).set_preview(summon_replace_ghost, summon_replace_insert_index)
#
	## Optional: give candidates a “selectable glow” immediately
	#for a in summon_replace_candidates:
		#_set_candidate_selectable_visuals(a, true)
#
#func _lock_for_modal_summon_replace() -> void:
	#wait_for_anims = true
	#hand.disable_hand_cards()
	#battle_ui.set_end_turn_enabled(false)
#
#func _make_summon_ghost(effect: SummonEffect) -> Node2D:
	#var ghost := Node2D.new()
	#var spr := Sprite2D.new()
	#ghost.add_child(spr)
#
	#var data: CombatantData = effect.summon_data
	#if data == null or data.character_art == null:
		#return ghost
#
	#spr.texture = data.character_art
#
	## tint + transparency (match combatant style)
	#var color := data.color_tint
	#color.a = 0.55
	#spr.modulate = color
#
	## match combatant scaling/offset
	#var scalar: float = float(data.height) / float(spr.texture.get_height())
	#spr.scale = Vector2(scalar, scalar)
	#spr.position = Vector2(0, -data.height / 2.0)
#
	## optional: ensure it draws on top of background / under fighters
	#ghost.z_index = 5
#
	#return ghost
#
#func _set_candidate_selectable_visuals(a: SummonedAlly, on: bool) -> void:
	#if on:
		#a.set_fade_mark(true)
	#else:
		#a.set_fade_mark(false)
#
#func _on_combatant_target_hovered(f: Fighter) -> void:
	#if interaction_mode != InteractionMode.SUMMON_REPLACE:
		#return
	#if f is SummonedAlly and summon_replace_candidates.has(f):
		#f.show_targeted_arrow()
		## optionally brighten glow, etc.
#
#func _on_combatant_target_unhovered(f: Fighter) -> void:
	#if interaction_mode != InteractionMode.SUMMON_REPLACE:
		#return
	#if f is SummonedAlly and summon_replace_candidates.has(f):
		#f.hide_targeted_arrow()
#
#func _on_combatant_target_clicked(f: Fighter) -> void:
	#if interaction_mode != InteractionMode.SUMMON_REPLACE:
		#return
	#if summon_replace_resolving:
		#return
#
	#if !(f is SummonedAlly):
		#return
	#if !summon_replace_candidates.has(f):
		#return
#
	#_confirm_summon_replace(f)
#
#func _confirm_summon_replace(chosen: SummonedAlly) -> void:
	#summon_replace_resolving = true
	#interaction_mode = InteractionMode.SUMMON_REPLACE
#
	## Turn off candidate clickability visuals now (optional)
	#for a in summon_replace_candidates:
		#_set_candidate_selectable_visuals(a, false)
#
	## Start fade animation
	#var tween := create_tween()
	#tween.tween_property(chosen.combatant.character_sprite, "modulate:a", 0.0, 0.18)
	#tween.finished.connect(func():
		#_finish_confirm_after_fade(chosen)
	#)
#
#func _finish_confirm_after_fade(chosen: SummonedAlly) -> void:
	## 1) Remove chosen (FADE PATH, not die())
	#var friendly := battle_scene.groups[0] as BattleGroupFriendly
	#friendly.combatant_faded(chosen) # step-7 method
#
	## 2) Remove preview ghost (so layout count stays correct)
	#friendly.clear_preview()
	#if summon_replace_ghost and is_instance_valid(summon_replace_ghost):
		#summon_replace_ghost.queue_free()
	#summon_replace_ghost = null
#
	## 3) Execute the summon
	## IMPORTANT: SummonEffect.execute() already adds the fighter to the group at insert_index
	#summon_replace_effect.execute()
	#summon_replace_effect.apply_to_card_context(summon_replace_ctx)
#
	## 4) Commit the card play (spend mana, run other actions, move card)
	#_commit_escrow_card_play()
#
	## 5) Exit modal
	#_end_summon_replace_mode()
#
#
### SOME OF THE CODE BELOW IS REPEATED FROM usable_card.gd
### WHICH IS STUPID AND I HATE IT ):<
#func _commit_escrow_card_play() -> void:
	#var card := summon_replace_card
	#var ctx := summon_replace_ctx
#
	## Spend mana now
	#ctx.player.spend_mana(ctx.card_data)
#
	## Execute all actions EXCEPT summon-slot ones (since we already executed effect)
	## It would feel better if these were performed by the usablecard
	## and not in battle.gd
	#var any_action := false
	#for action: CardAction in ctx.card_data.actions:
		#if action.requires_summon_slot():
			#continue
		#if action.activate(ctx):
			#any_action = true
#
	#Events.card_played.emit(card)
#
	## Destination logic (same as UsableCard.activate)
	#if ctx.card_data.deplete:
		#card.hand.deplete_card(card.hand.remove_card_by_entity(card))
	#elif ctx.card_data.card_type == CardData.CardType.SUMMON:
		#card.hand.reserve_summon_card(card.hand.remove_card_by_entity(card))
	#else:
		#card.hand.discard_card(card.hand.remove_card_by_entity(card))
#
#func _on_summon_replace_cancel_requested() -> void:
	#if interaction_mode != InteractionMode.SUMMON_REPLACE:
		#return
	#_cancel_summon_replace()
#
#func _cancel_summon_replace() -> void:
	#summon_replace_resolving = false
	#var friendly := battle_scene.groups[0] as BattleGroupFriendly
#
	#friendly.clear_preview()
	#if summon_replace_ghost and is_instance_valid(summon_replace_ghost):
		#summon_replace_ghost.queue_free()
#
	#for a in summon_replace_candidates:
		#_set_candidate_selectable_visuals(a, false)
#
	#_end_summon_replace_mode()
#
#func _end_summon_replace_mode() -> void:
	#summon_replace_resolving = false
	#battle_ui.show_summon_replace_prompt(false)
	#battle_ui.set_end_turn_enabled(true)
	#wait_for_anims = false
#
	## Clear escrow
	#summon_replace_card = null
	#summon_replace_ctx = null
	#summon_replace_effect = null
	#summon_replace_candidates.clear()
	#summon_replace_ghost = null
#
	#interaction_mode = InteractionMode.NORMAL
#
	## IMPORTANT: restore pending turn glow after messing with it
	#(battle_scene.groups[0] as BattleGroupFriendly)._update_pending_turn_glow()
	#hand.enable_hand_cards()
