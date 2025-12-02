class_name BattleRewardsScreen extends Control

#enum Type {GOLD, NEW_CARD, RELIC}

const CARD_REWARD = preload("res://scenes/card_reward.tscn")
const REWARD_BUTTON := preload("res://scenes/ui/reward_button.tscn")
const GOLD_TEXTURE := preload("res://assets/sprites/assorted/coin.PNG")
const GOLD_TEXT := "%s gold"
const CARD_TEXTURE := preload("res://assets/sprites/assorted/diamond_white.png")
const CARD_TEXT := "Add New Card"

@export var run_account: RunAccount
@export var player_data: CombatantData
@export var arcanum_system: ArcanaSystem

@onready var rewards: VBoxContainer = %Rewards

var card_reward_total_weight : float = 0.0

var card_rarity_weights := {
	CardData.Rarity.COMMON: 0.0,
	CardData.Rarity.UNCOMMON: 0.0,
	CardData.Rarity.RARE: 0.0
}

func _ready() -> void:
	for node: Node in rewards.get_children():
		node.queue_free()

func add_gold_reward(n_gold: int) -> void:
	var gold_reward := REWARD_BUTTON.instantiate() as RewardButton
	gold_reward.reward_texture = GOLD_TEXTURE
	gold_reward.reward_text = GOLD_TEXT % n_gold
	gold_reward.pressed.connect(_on_gold_reward_taken.bind(n_gold))
	rewards.add_child.call_deferred(gold_reward)

func add_card_reward() -> void:
	var card_reward_button := REWARD_BUTTON.instantiate() as RewardButton
	card_reward_button.reward_texture = CARD_TEXTURE
	card_reward_button.reward_text = CARD_TEXT
	card_reward_button.pressed.connect(_show_card_reward)
	rewards.add_child.call_deferred(card_reward_button)

func add_arcanum_reward(arcanum: Arcanum) -> void:
	var arcanum_reward := REWARD_BUTTON.instantiate() as RewardButton
	arcanum_reward.reward_texture = arcanum.icon
	arcanum_reward.reward_text = arcanum.arcanum_name
	arcanum_reward.pressed.connect(_on_arcanum_reward_taken.bind(arcanum))
	rewards.add_child.call_deferred(arcanum_reward)

func _on_arcanum_reward_taken(arcanum: Arcanum) -> void:
	pass

func _show_card_reward() -> void:
	if !run_account or !player_data:
		return
	
	var card_reward := CARD_REWARD.instantiate() as CardReward
	add_child(card_reward)
	card_reward.card_reward_selected.connect(_on_card_reward_taken)
	
	var card_choices: Array[CardData] = []
	var possible_cards: Array[CardData] = run_account.draftable_cards.cards
	
	for i in run_account.card_reward_choices:
		_calculate_card_chances()
		var roll := randf_range(0.0, card_reward_total_weight)
		
		for rarity: CardData.Rarity in card_rarity_weights:
			if card_rarity_weights[rarity] > roll:
				_modify_weights(rarity)
				var rolled_card := _get_random_possible_card(possible_cards, rarity)
				card_choices.append(rolled_card)
				#THIS NEEDS TO BE REVISITED BECAUSE CARDS SHOULD POSSIBLY BE REMOVED FROM THE POOL
				#BUT IT WAS CAUSING AN ERROR WHEN NO CARDS OF A CERTAIN RARITY WERE LEFT
				#possible_cards.erase(rolled_card) #is this erasing the rolled card from run_account.draftable_cards.cards?
				break
	
	card_reward.card_choices = card_choices
	card_reward.show()

func _calculate_card_chances() -> void:
	card_reward_total_weight = run_account.common_weight + run_account.uncommon_weight + run_account.rare_weight
	card_rarity_weights[CardData.Rarity.COMMON] = run_account.common_weight
	card_rarity_weights[CardData.Rarity.UNCOMMON] = run_account.common_weight + run_account.uncommon_weight
	card_rarity_weights[CardData.Rarity.RARE] = card_reward_total_weight

func _modify_weights(rarity_rolled: CardData.Rarity) -> void:
	if rarity_rolled == CardData.Rarity.RARE:
		run_account.rare_weight = RunAccount.BASE_RARE_WEIGHT
	else:
		run_account.rare_weight = clampf(run_account.rare_weight + 0.3, run_account.BASE_RARE_WEIGHT, 5.0)

func _get_random_possible_card(possible_cards: Array[CardData], rarity: CardData.Rarity) -> CardData:
	var all_possible_cards := possible_cards.filter(
		func(card: CardData):
			return card.rarity == rarity
	)
	return all_possible_cards.pick_random()

func _on_gold_reward_taken(n_gold: int) -> void:
	if !run_account:
		return
	run_account.gold += n_gold

func _on_card_reward_taken(card: CardData) -> void:
	if !player_data or !card or !run_account.deck:
		return
	run_account.deck.add_card(card)

func _on_back_button_pressed() -> void:
	Events.battle_rewards_exited.emit()
