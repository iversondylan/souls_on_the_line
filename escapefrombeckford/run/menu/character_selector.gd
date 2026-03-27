extends Control

const RUN_SCENE = preload("res://run/flow/run.tscn")
const COLE_STATS := preload("res://character_profiles/Cole/cole_data.tres")
const COLE_BASIC_DECK := preload("res://character_profiles/Cole/cole_basic_deck.tres")
const COLE_DRAFTABLE_CARDS := preload("res://character_profiles/Cole/cole_draftable_cards.tres")

@export var run_startup: RunStartup = preload("res://run/flow/run_startup.tres")

@onready var title: Label = %Title
@onready var description: Label = %Description
@onready var character_image: TextureRect = %CharacterImage

var current_character: PlayerData : set = set_current_character
var current_deck: CardPile : set = set_current_card_pile
var current_draftable_cards: CardPile : set = set_current_draftable_cards

func _ready() -> void:
	set_current_character(COLE_STATS)
	set_current_card_pile(COLE_BASIC_DECK)
	set_current_draftable_cards(COLE_DRAFTABLE_CARDS)
	
func set_current_character(new_character: PlayerData) -> void:
	current_character = new_character
	title.text = current_character.name
	description.text = current_character.description
	character_image.texture = current_character.load_portrait_art()

func set_current_card_pile(new_deck: CardPile) -> void:
	current_deck = new_deck

func set_current_draftable_cards(new_draftable_cards: CardPile) -> void:
	current_draftable_cards = new_draftable_cards

func _on_start_button_pressed() -> void:
	print("Start new escape attempt with %s" % current_character.name)
	run_startup.startup_type = RunStartup.StartupType.NEW_RUN
	run_startup.run_seed = 0
	run_startup.selected_starting_soul_uid = ""
	run_startup.player_definition = current_character
	run_startup.starting_deck = current_deck
	run_startup.draftable_cards = current_draftable_cards
	get_tree().change_scene_to_packed(RUN_SCENE)


func _on_cole_button_pressed() -> void:
	current_character = COLE_STATS
	current_deck = COLE_BASIC_DECK
	current_draftable_cards = COLE_DRAFTABLE_CARDS


func _on_char_2_button_pressed() -> void:
	current_character = COLE_STATS
	current_deck = COLE_BASIC_DECK
	current_draftable_cards = COLE_DRAFTABLE_CARDS

func _on_char_3_button_pressed() -> void:
	current_character = COLE_STATS
	current_deck = COLE_BASIC_DECK
	current_draftable_cards = COLE_DRAFTABLE_CARDS
