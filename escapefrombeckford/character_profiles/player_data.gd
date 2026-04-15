# player_data.gd

class_name PlayerData extends CombatantData

@export var profile_id: String = ""
@export var starting_arcanum: Arcanum
@export var possible_arcana: Arcana
@export var starter_soul: CardData
@export var starting_deck: CardPile
@export var draftable_cards: CardPile
@export var bonus_starting_gold: int

@export var arcana_reward_pool: ArcanaRewardPool
