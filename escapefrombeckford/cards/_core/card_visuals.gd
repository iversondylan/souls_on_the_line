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

const OVERLOAD_PIP := preload("uid://pe4lgl2dwu32")
const OVERLOAD_1_COLOR := Color(1.0, 0.88, 0.22, 1.0)
const OVERLOAD_2_COLOR := Color(1.0, 0.56, 0.12, 1.0)
const OVERLOAD_3_COLOR := Color(0.9, 0.18, 0.18, 1.0)
const OVERLOAD_4_PLUS_COLOR := Color(0.45, 0.06, 0.06, 1.0)

@export var card_data: CardData : set = _set_card_data
var cost_red: int = 0 : set = set_cost_red
var cost_green: int = 0 : set = set_cost_green
var cost_blue: int = 0 : set = set_cost_blue
var overload: int = 0
var _card_data_internal: CardData
var mana_panel_radius: float
var _default_cost_label_modulate: Color = Color.WHITE

func _ready() -> void:
	mana_panel_radius = cost_container.texture.get_size().y * cost_container.scale.y * 0.5-0.75
	_default_cost_label_modulate = cost_label.modulate
	refresh_from_card_data()

func set_overload(amount: int) -> void:
	overload = maxi(int(amount), 0)
	for pip in _get_overload_pips():
		pip.queue_free()
	for _i in range(overload):
		cost_display.add_child(OVERLOAD_PIP.instantiate())
	reposition_overload_pips()
	_refresh_cost_label_color()

func _set_card_data(value: CardData) -> void:
	assert(value != null, "CardVisuals received null CardData")
	if !is_node_ready():
		await ready
	_card_data_internal = value
	name_label.text = value.name
	#cost_red = value.cost_red
	#cost_green = value.cost_green
	#cost_blue = value.cost_blue
	refresh_from_card_data()
	card_art_rect.texture = value.texture
	rarity.modulate = CardData.RARITY_COLORS[value.rarity]

func refresh_from_card_data() -> void:
	if !is_node_ready():
		await ready
	if _card_data_internal == null:
		set_overload(0)
		cost_label.text = "0"
		cost_label.modulate = _default_cost_label_modulate
		return

	set_overload(int(_card_data_internal.overload))
	set_total_cost()

func set_description(new_description: String) -> void:
	description.set_text(new_description)

func set_total_cost() -> void:
	if _card_data_internal == null:
		return
	cost_label.text = str(_card_data_internal.get_total_cost())
	_refresh_cost_label_color()
	

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
	#print("overload: ", overload, " angle: ", angle_deg_flt, " x: ", x, " y: ", y)
	return Vector2(x, y)#cost_display.position + Vector2(x, y)

func _update_pip_transform(pip: OverloadPip, angle_in_drag: float) -> void:
	var pos: Vector2 = get_pip_position(angle_in_drag)
	pip.position = pos

func _refresh_cost_label_color() -> void:
	if cost_label == null:
		return

	match overload:
		0:
			cost_label.modulate = _default_cost_label_modulate
		1:
			cost_label.modulate = OVERLOAD_1_COLOR
		2:
			cost_label.modulate = OVERLOAD_2_COLOR
		3:
			cost_label.modulate = OVERLOAD_3_COLOR
		_:
			cost_label.modulate = OVERLOAD_4_PLUS_COLOR
