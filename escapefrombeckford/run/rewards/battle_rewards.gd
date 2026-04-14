# battle_rewards.gd

class_name BattleRewardsScreen extends Control

#enum Type {GOLD, NEW_CARD, RELIC}

const MENU_CARD := preload("uid://d4g7iin5x7648")
const REWARD_BUTTON := preload("uid://clfrebjlfonlo")
const GOLD_TEXTURE := preload("uid://cbbohhy0ybxvy")
const GOLD_TEXT := "%s gold"
const CARD_TEXTURE := preload("uid://cptf1w3wpa2ah")
const CARD_TEXT := "Add New Card"

@export var run_state: RunState
@export var player_data: PlayerData
var arcanum_system: ArcanaSystem
var arcana_system_container: ArcanaSystemContainer
var run: Run

@onready var rewards: VBoxContainer = %Rewards
@onready var card_choices_section: VBoxContainer = %CardChoicesSection
@onready var card_choice_container: HBoxContainer = %CardChoiceContainer
@onready var card_reward_skip_button: Button = %CardRewardSkipButton
@onready var card_reward_take_button: Button = %CardRewardTakeButton
var reward_context: RewardContext

var card_reward_total_weight : float = 0.0
var _selected_reward_card: CardData
var _current_card_reward_button: RewardButton

var card_rarity_weights := {
	CardData.Rarity.COMMON: 0.0,
	CardData.Rarity.UNCOMMON: 0.0,
	CardData.Rarity.RARE: 0.0
}

func _ready() -> void:
	card_reward_skip_button.pressed.connect(_on_card_reward_taken.bind(null))
	card_reward_take_button.pressed.connect(_take_selected_reward_card)
	_clear_rewards()

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
		add_card_reward(ctx.card_choices)

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
	gold_reward.pressed.connect(_on_gold_reward_taken.bind(n_gold, reward_index))
	rewards.add_child.call_deferred(gold_reward)

func add_card_reward(card_choices: Array[CardData]) -> void:
	var card_reward_button := REWARD_BUTTON.instantiate() as RewardButton
	card_reward_button.reward_texture = CARD_TEXTURE
	card_reward_button.reward_text = CARD_TEXT
	card_reward_button.pressed.connect(_show_card_reward.bind(card_choices))
	_current_card_reward_button = card_reward_button
	rewards.add_child.call_deferred(card_reward_button)

func add_arcanum_reward(arcanum: Arcanum, reward_index: int) -> void:
	var arcanum_reward := REWARD_BUTTON.instantiate() as RewardButton
	arcanum_reward.reward_texture = arcanum.icon
	arcanum_reward.reward_text = arcanum.arcanum_name
	arcanum_reward.pressed.connect(_on_arcanum_reward_taken.bind(arcanum, reward_index))
	rewards.add_child.call_deferred(arcanum_reward)

func _on_arcanum_reward_taken(arcanum: Arcanum, reward_index: int) -> void:
	if !arcanum or !arcana_system_container:
		return
	
	arcana_system_container.add_arcanum(arcanum)
	if run_state != null and !run_state.pending_reward_claimed_arcanum_indices.has(reward_index):
		run_state.pending_reward_claimed_arcanum_indices.append(reward_index)
	if run != null:
		run._persist_active_run()

func _show_card_reward(card_choices: Array[CardData]) -> void:
	if !run_state or card_choices.is_empty():
		return
	card_choices_section.visible = true
	card_reward_take_button.disabled = true
	_selected_reward_card = null

	for child in card_choice_container.get_children():
		child.queue_free()

	for card_data in card_choices:
		var wrapper := PanelContainer.new()
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		card_choice_container.add_child(wrapper)
		wrapper.modulate = Color(0.72, 0.72, 0.72, 1.0)

		var menu_card := MENU_CARD.instantiate() as MenuCard
		menu_card.mouse_filter = Control.MOUSE_FILTER_STOP
		wrapper.add_child(menu_card)
		menu_card.set_card_data(card_data)
		menu_card.tooltip_requested.connect(_on_reward_card_selected.bind(wrapper))

	if _current_card_reward_button != null:
		_current_card_reward_button.visible = false

func _calculate_card_chances() -> void:
	card_reward_total_weight = run_state.common_weight + run_state.uncommon_weight + run_state.rare_weight
	card_rarity_weights[CardData.Rarity.COMMON] = run_state.common_weight
	card_rarity_weights[CardData.Rarity.UNCOMMON] = run_state.common_weight + run_state.uncommon_weight
	card_rarity_weights[CardData.Rarity.RARE] = card_reward_total_weight

func _modify_weights(rarity_rolled: CardData.Rarity) -> void:
	if rarity_rolled == CardData.Rarity.RARE:
		run_state.rare_weight = RunState.BASE_RARE_WEIGHT
	else:
		run_state.rare_weight = clampf(run_state.rare_weight + 0.3, RunState.BASE_RARE_WEIGHT, 5.0)

func _on_gold_reward_taken(n_gold: int, reward_index: int) -> void:
	if !run_state:
		return
	run_state.gold += n_gold
	if !run_state.pending_reward_claimed_gold_indices.has(reward_index):
		run_state.pending_reward_claimed_gold_indices.append(reward_index)
	if run != null:
		run._persist_active_run()

func _on_card_reward_taken(card: CardData) -> void:
	if run_state == null:
		return
	if card != null and run_state.run_deck:
		run_state.run_deck.add_card(card)
	run_state.pending_reward_card_claimed = true
	card_choices_section.visible = false
	for child in card_choice_container.get_children():
		child.queue_free()
	_current_card_reward_button = null
	_selected_reward_card = null
	if run != null:
		run._persist_active_run()


func _on_reward_card_selected(card: CardData, wrapper: PanelContainer) -> void:
	_selected_reward_card = card
	card_reward_take_button.disabled = false
	for child in card_choice_container.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate = Color(0.72, 0.72, 0.72, 1.0)
	wrapper.modulate = Color.WHITE


func _take_selected_reward_card() -> void:
	if _selected_reward_card == null:
		return
	_on_card_reward_taken(_selected_reward_card)

func _on_back_button_pressed() -> void:
	if run != null:
		run._persist_active_run()
	Events.battle_rewards_exited.emit()

func _clear_rewards() -> void:
	for node: Node in rewards.get_children():
		if node == card_choices_section:
			continue
		node.queue_free()
	card_choices_section.visible = false
	card_reward_take_button.disabled = true
	for child in card_choice_container.get_children():
		child.queue_free()
	_current_card_reward_button = null
	_selected_reward_card = null
