class_name CardVisuals extends Control

@export var card_data: CardData : set = set_card_data

@onready var glow: Sprite2D = %Glow
@onready var card_front: TextureRect = %CardFront
@onready var cost_blue_sprites: AnimatedSprite2D = %CostBlue
@onready var cost_red_sprites: AnimatedSprite2D = %CostRed
@onready var cost_green_sprites: AnimatedSprite2D = %CostGreen
@onready var cost_container: Sprite2D = %CostContainer
@onready var name_label: RichTextLabel = %NameLabel
@onready var card_art_rect: TextureRect = %CardArtRect
@onready var card_name_box: TextureRect = %CardNameBox
@onready var description: RichTextLabel = %Description
@onready var rarity: TextureRect = %Rarity

var cost_red: int = 0 : set = set_cost_red
var cost_green: int = 0 : set = set_cost_green
var cost_blue: int = 0 : set = set_cost_blue

func set_card_data(_card_data: CardData) -> void:
	if !is_node_ready():
		await ready
	card_data = _card_data
	name_label.text = card_data.name
	cost_red = _card_data.cost_red
	cost_green = _card_data.cost_green
	cost_blue = _card_data.cost_blue
	card_art_rect.texture = _card_data.texture
	rarity.modulate = CardData.RARITY_COLORS[card_data.rarity]

func set_cost_red(cost: int) -> void:
	cost_red = cost
	match cost_red:
		0:
			cost_red_sprites.frame = 0
		1:
			cost_red_sprites.frame = 1

func set_cost_green(cost: int) -> void:
	cost_green = cost
	match cost_green:
		0:
			cost_green_sprites.frame = 0
		1:
			cost_green_sprites.frame = 1

func set_cost_blue(cost: int) -> void:
	cost_blue = cost
	match cost_blue:
		0:
			cost_blue_sprites.frame = 0
		1:
			cost_blue_sprites.frame = 1
