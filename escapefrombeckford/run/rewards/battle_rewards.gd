# battle_rewards.gd

class_name BattleRewardsScreen extends Control

#enum Type {GOLD, NEW_CARD, RELIC}

const CARD_SELECTION_OVERLAY := preload("res://run/ui/card_selection_overlay.tscn")
const CONFIRMATION_PROMPT_SCN := preload("res://ui/confirmation_prompt.tscn")
const REWARD_BUTTON := preload("uid://clfrebjlfonlo")
const GOLD_TEXTURE := preload("uid://cbbohhy0ybxvy")
const GOLD_TEXT := "%s gold"
const CARD_TEXTURE := preload("uid://cptf1w3wpa2ah")
const CARD_TEXT := "Add New Card"
const SOULBOUND_CARD_TEXT := "Add Soulbound Card"
const SOULBOUND_REWARD_ICON_MODULATE := Color(0.65, 0.35, 1.0, 1.0)

enum CardRewardKind {
	NORMAL,
	SOULBOUND,
}

@export var run_state: RunState
@export var player_data: PlayerData
var arcanum_system: ArcanaSystem
var arcana_system_container: ArcanaSystemContainer
var run: Run

@onready var rewards: VBoxContainer = %Rewards
var reward_context: RewardContext

var _current_card_reward_button: RewardButton
var _current_soulbound_card_reward_button: RewardButton
var _card_reward_overlay: CardSelectionOverlay
var _confirm_dialog
var _pending_reward_card: CardData
var _pending_reward_slot_index: int = -1
var _active_card_reward_kind: int = CardRewardKind.NORMAL

func _ready() -> void:
	_clear_rewards()
	_build_confirm_dialog()

func populate_from_context(ctx: RewardContext) -> void:
	if ctx == null:
		return
	reward_context = ctx
	_clear_rewards()

	for i in range(ctx.gold_rewards.size()):
		if ctx.claimed_gold_indices.has(i):
			continue
		add_gold_reward(int(ctx.gold_rewards[i]), i)

	if bool(ctx.include_card_reward) and !ctx.card_reward_claimed:
		add_card_reward(ctx.card_choices, CardRewardKind.NORMAL)

	if bool(ctx.include_soulbound_card_reward) and !ctx.soulbound_card_reward_claimed:
		add_card_reward(ctx.soulbound_card_choices, CardRewardKind.SOULBOUND)

	for i in range(ctx.arcanum_rewards.size()):
		if ctx.claimed_arcanum_indices.has(i):
			continue
		var arcanum: Arcanum = ctx.arcanum_rewards[i]
		if arcanum != null:
			add_arcanum_reward(arcanum, i)

func add_gold_reward(n_gold: int, reward_index: int) -> void:
	var gold_reward := REWARD_BUTTON.instantiate() as RewardButton
	gold_reward.reward_texture = GOLD_TEXTURE
	gold_reward.reward_text = GOLD_TEXT % n_gold
	gold_reward.pressed.connect(_on_gold_reward_taken.bind(n_gold, reward_index, gold_reward))
	rewards.add_child.call_deferred(gold_reward)

func add_card_reward(card_choices: Array[CardData], reward_kind: int) -> void:
	var card_reward_button := REWARD_BUTTON.instantiate() as RewardButton
	card_reward_button.reward_texture = CARD_TEXTURE
	if int(reward_kind) == int(CardRewardKind.SOULBOUND):
		card_reward_button.reward_text = SOULBOUND_CARD_TEXT
		card_reward_button.reward_icon_modulate = SOULBOUND_REWARD_ICON_MODULATE
		card_reward_button.pressed.connect(_show_card_reward.bind(card_choices, reward_kind))
		_current_soulbound_card_reward_button = card_reward_button
	else:
		card_reward_button.reward_text = CARD_TEXT
		card_reward_button.pressed.connect(_show_card_reward.bind(card_choices, reward_kind))
		_current_card_reward_button = card_reward_button
	rewards.add_child.call_deferred(card_reward_button)

func add_arcanum_reward(arcanum: Arcanum, reward_index: int) -> void:
	var arcanum_reward := REWARD_BUTTON.instantiate() as RewardButton
	arcanum_reward.reward_texture = arcanum.icon
	arcanum_reward.reward_text = arcanum.arcanum_name
	arcanum_reward.pressed.connect(_on_arcanum_reward_taken.bind(arcanum, reward_index, arcanum_reward))
	rewards.add_child.call_deferred(arcanum_reward)

func _on_arcanum_reward_taken(arcanum: Arcanum, reward_index: int, reward_button: RewardButton) -> void:
	if !arcanum or !arcana_system_container:
		return
	
	arcana_system_container.add_arcanum(arcanum)
	if run_state != null and !run_state.pending_reward_claimed_arcanum_indices.has(reward_index):
		run_state.pending_reward_claimed_arcanum_indices.append(reward_index)
	if is_instance_valid(reward_button):
		reward_button.queue_free()
	if run != null:
		run._persist_active_run()

func _show_card_reward(card_choices: Array[CardData], reward_kind: int = CardRewardKind.NORMAL) -> void:
	if !run_state or card_choices.is_empty():
		return
	if is_instance_valid(_card_reward_overlay):
		_card_reward_overlay.queue_free()

	_active_card_reward_kind = int(reward_kind)
	_card_reward_overlay = CARD_SELECTION_OVERLAY.instantiate() as CardSelectionOverlay
	add_child(_card_reward_overlay)
	_card_reward_overlay.selection_confirmed.connect(_on_card_reward_taken)
	_card_reward_overlay.selection_canceled.connect(_on_card_reward_selection_canceled)
	_card_reward_overlay.tree_exited.connect(_on_card_reward_overlay_exited)
	_card_reward_overlay.configure(
		card_choices,
		"Choose a Soulbound Card" if int(reward_kind) == int(CardRewardKind.SOULBOUND) else "Choose a Card",
		"Take",
		"Cancel"
	)

func _on_gold_reward_taken(n_gold: int, reward_index: int, reward_button: RewardButton) -> void:
	if !run_state:
		return
	run_state.gold += n_gold
	if !run_state.pending_reward_claimed_gold_indices.has(reward_index):
		run_state.pending_reward_claimed_gold_indices.append(reward_index)
	if is_instance_valid(reward_button):
		reward_button.queue_free()
	if run != null:
		run._persist_active_run()

func _on_card_reward_taken(card: CardData) -> void:
	if run_state == null or card == null:
		return
	if card.is_soulbound_slot_card() and run_state.run_deck != null and run_state.run_deck.has_soulbound_roster_enabled():
		_pending_reward_card = card
		_show_soulbound_slot_overlay()
		return
	if run_state.run_deck:
		run_state.run_deck.add_normal_card(card)
	_mark_active_card_reward_claimed()
	_card_reward_overlay = null
	if run != null:
		run._persist_active_run()


func _on_card_reward_selection_canceled() -> void:
	if _pending_reward_card != null and reward_context != null:
		_pending_reward_card = null
		_pending_reward_slot_index = -1
		_show_card_reward(_active_reward_choices(), _active_card_reward_kind)
		return
	_card_reward_overlay = null


func _on_card_reward_overlay_exited() -> void:
	if is_instance_valid(_card_reward_overlay):
		return
	_card_reward_overlay = null

func _on_back_button_pressed() -> void:
	if run != null:
		run._persist_active_run()
	Events.battle_rewards_exited.emit()

func _clear_rewards() -> void:
	for node: Node in rewards.get_children():
		node.queue_free()
	if is_instance_valid(_card_reward_overlay):
		_card_reward_overlay.queue_free()
	_card_reward_overlay = null
	_current_card_reward_button = null
	_current_soulbound_card_reward_button = null


func _build_confirm_dialog() -> void:
	_confirm_dialog = CONFIRMATION_PROMPT_SCN.instantiate()
	if _confirm_dialog == null:
		return
	_confirm_dialog.confirmed.connect(_confirm_reward_soulbound_replacement)
	_confirm_dialog.canceled.connect(_clear_pending_reward_replacement)
	add_child(_confirm_dialog)


func _show_soulbound_slot_overlay() -> void:
	if run_state == null or run_state.run_deck == null or !run_state.run_deck.has_soulbound_roster_enabled():
		return
	if is_instance_valid(_card_reward_overlay):
		_card_reward_overlay.queue_free()
	_card_reward_overlay = CARD_SELECTION_OVERLAY.instantiate() as CardSelectionOverlay
	add_child(_card_reward_overlay)
	_card_reward_overlay.selection_confirmed.connect(_on_soulbound_slot_selected)
	_card_reward_overlay.selection_canceled.connect(_on_card_reward_selection_canceled)
	_card_reward_overlay.tree_exited.connect(_on_card_reward_overlay_exited)
	_card_reward_overlay.configure(
		run_state.run_deck.get_soulbound_slot_cards(),
		"Choose a Soulbound Slot to Replace",
		"Replace",
		"Back"
	)


func _on_soulbound_slot_selected(slot_card: CardData) -> void:
	if slot_card == null or _pending_reward_card == null or run_state == null or run_state.run_deck == null:
		return
	_pending_reward_slot_index = _find_soulbound_slot_index(slot_card)
	if _pending_reward_slot_index < 0:
		return
	_confirm_dialog.open(
		"Replace %s with %s for this run?" % [slot_card.name, _pending_reward_card.name],
		"Replace",
		"Cancel"
	)


func _confirm_reward_soulbound_replacement() -> void:
	if run_state == null or run_state.run_deck == null or _pending_reward_card == null or _pending_reward_slot_index < 0:
		return
	if !run_state.run_deck.replace_soulbound_slot(_pending_reward_slot_index, _pending_reward_card):
		return
	_mark_active_card_reward_claimed()
	_clear_pending_reward_replacement()
	if run != null:
		run._persist_active_run()


func _clear_pending_reward_replacement() -> void:
	_pending_reward_card = null
	_pending_reward_slot_index = -1


func _active_reward_choices() -> Array[CardData]:
	if reward_context == null:
		var empty: Array[CardData] = []
		return empty
	if int(_active_card_reward_kind) == int(CardRewardKind.SOULBOUND):
		return reward_context.soulbound_card_choices
	return reward_context.card_choices


func _mark_active_card_reward_claimed() -> void:
	if run_state == null:
		return
	if int(_active_card_reward_kind) == int(CardRewardKind.SOULBOUND):
		run_state.pending_reward_soulbound_card_claimed = true
		if is_instance_valid(_current_soulbound_card_reward_button):
			_current_soulbound_card_reward_button.queue_free()
		_current_soulbound_card_reward_button = null
		return
	run_state.pending_reward_card_claimed = true
	if is_instance_valid(_current_card_reward_button):
		_current_card_reward_button.queue_free()
	_current_card_reward_button = null


func _find_soulbound_slot_index(slot_card: CardData) -> int:
	if slot_card == null or run_state == null or run_state.run_deck == null:
		return -1
	slot_card.ensure_uid()
	var slot_cards := run_state.run_deck.get_soulbound_slot_cards()
	for slot_index in range(slot_cards.size()):
		var current := slot_cards[slot_index]
		if current == null:
			continue
		current.ensure_uid()
		if String(current.uid) == String(slot_card.uid):
			return slot_index
	return -1
