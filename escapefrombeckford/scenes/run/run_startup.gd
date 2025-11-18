class_name RunStartup
extends Resource

enum StartupType {NEW_RUN, CONTINUED_RUN}

@export var startup_type: StartupType
@export var player_data: PlayerData
@export var deck: CardPile
@export var draftable_cards: CardPile
@export var available_arcana: Arcana
