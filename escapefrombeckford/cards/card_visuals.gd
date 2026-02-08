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
@onready var cost_display: Node2D = %CostDisplay

@export var card_angle_limit_flt: float = 180
@export var max_card_spread_angle_flt: float = 38

const OVERLOAD_PIP := preload("res://cards/overload_pip.tscn")

@export var card_data: CardData : set = _set_card_data
var cost_red: int = 0 : set = set_cost_red
var cost_green: int = 0 : set = set_cost_green
var cost_blue: int = 0 : set = set_cost_blue
var _card_data_internal: CardData
var mana_panel_radius: float

func _ready() -> void:
	mana_panel_radius = cost_container.texture.get_size().y * cost_container.scale.y * 0.5 + 2.0
	cost_display.add_child(OVERLOAD_PIP.instantiate())
	cost_display.add_child(OVERLOAD_PIP.instantiate())
	cost_display.add_child(OVERLOAD_PIP.instantiate())
	reposition_overload_pips()

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

func _get_overload_pips() -> Array[OverloadPip]:
	var pips: Array[OverloadPip] = []
	for child in cost_display.get_children():
		if child is OverloadPip:
			pips.push_back(child)
	return pips

func reposition_overload_pips() -> void:
	var pips := _get_overload_pips()
	var pip_spread_angle_flt: float = 0
	var current_pip_angle_flt: float = 0
	var pip_angle_increment_flt: float = 0

	if pips.size() >= 2:
		pip_spread_angle_flt = min(card_angle_limit_flt, max_card_spread_angle_flt * (pips.size() - 1))
		current_pip_angle_flt = -pip_spread_angle_flt / 2
		pip_angle_increment_flt = pip_spread_angle_flt / (pips.size() - 1)

	for pip in pips:
		_update_pip_transform(pip, current_pip_angle_flt)
		current_pip_angle_flt += pip_angle_increment_flt

func get_pip_position(angle_deg_flt: float) -> Vector2:
	var x: float = mana_panel_radius * cos(deg_to_rad(angle_deg_flt + 270))
	var y: float = mana_panel_radius * sin(deg_to_rad(angle_deg_flt + 270))
	return Vector2(x, y)#cost_display.position + Vector2(x, y)

func _update_pip_transform(pip: OverloadPip, angle_in_drag: float) -> void:
	var pos: Vector2 = get_pip_position(angle_in_drag)
	pip.position = pos
