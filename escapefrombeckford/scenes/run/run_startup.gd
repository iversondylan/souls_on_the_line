# run_startup.gd

class_name RunStartup
extends Resource

enum StartupType {NEW_RUN, CONTINUED_RUN}

@export var startup_type: StartupType
@export var player_data: PlayerData
@export var arcana_catalog: Arcana
@export var run_seed: int = 0  # 0 means "generate one
#@export var deck: CardPile
#@export var draftable_cards: CardPile
#@export var available_arcana: Arcana
