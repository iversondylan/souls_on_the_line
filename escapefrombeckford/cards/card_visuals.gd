# card_visuals.gd

class_name CardVisuals extends Control

@onready var glow: Sprite2D = %Glow
@onready var card_front: TextureRect = %CardFront
@onready var cost_blue_sprites: AnimatedSprite2D = %CostBlue
@onready var cost_red_sprites: AnimatedSprite2D = %CostRed
@onready var cost_green_sprites: AnimatedSprite2D = %CostGreen
@onready var cost_container: Sprite2D = %CostContainer
@onready var name_label: RichTextLabel = %NameLabel
@onready var card_art_rect: TextureRect = %CardArtRect
@onready var card_name_box: Sprite2D = %CardNameBox
@onready var description: RichTextLabel = %Description
@onready var rarity: TextureRect = %Rarity
@onready var card_strictly_visuals: Node2D = $CardStrictlyVisuals
@onready var cost_label: Label = $CardStrictlyVisuals/CornerMan/CostDisplay/CostLabel


@export var card_data: CardData : set = _set_card_data
var cost_red: int = 0 : set = set_cost_red
var cost_green: int = 0 : set = set_cost_green
var cost_blue: int = 0 : set = set_cost_blue
var _card_data_internal: CardData

func _set_card_data(value: CardData) -> void:
	assert(value != null, "CardVisuals received null CardData")
	if !is_node_ready():
		await ready
	_card_data_internal = value
	name_label.text = value.name
	#cost_red = value.cost_red
	#cost_green = value.cost_green
	#cost_blue = value.cost_blue
	set_total_cost()
	card_art_rect.texture = value.texture
	rarity.modulate = CardData.RARITY_COLORS[value.rarity]

func set_description(new_description: String) -> void:
	description.set_text(new_description)

func set_total_cost() -> void:
	cost_label.text = str(_card_data_internal.get_total_cost())
	

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
