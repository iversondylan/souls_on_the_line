class_name CardButton extends Button

@export var card_data: CardData : set = set_card_data
@export var caption_text: String = "" : set = set_caption_text
@export var button_minimum_size: Vector2 = Vector2(275, 426) : set = set_button_minimum_size
@export var card_size: Vector2 = Vector2(275, 370) : set = set_card_size

#@export_range(0, 128, 1) var label_min_height: int = 28 : set = set_label_min_height
#@export_range(0, 64, 1) var content_separation: int = 6 : set = set_content_separation
#@export_range(0, 64, 1) var label_font_size: int = 24 : set = set_label_font_size
#@export_range(0, 64, 1) var content_margin_left: int = 0 : set = set_content_margin_left
#@export_range(0, 64, 1) var content_margin_top: int = 8 : set = set_content_margin_top
#@export_range(0, 64, 1) var content_margin_right: int = 0 : set = set_content_margin_right
#@export_range(0, 64, 1) var content_margin_bottom: int = 14 : set = set_content_margin_bottom

@onready var margin_container: MarginContainer = $MarginContainer
@onready var content: VBoxContainer = $MarginContainer/Content
@onready var card_wrapper: Control = $MarginContainer/Content/CardWrapper
@onready var menu_card: MenuCard = $MarginContainer/Content/CardWrapper/MenuCard
@onready var caption_label: Label = $MarginContainer/Content/CaptionLabel


func _ready() -> void:
	_set_mouse_passthrough(margin_container)
	_apply_layout()
	_apply_content()


func configure(new_card_data: CardData, new_caption_text: String) -> void:
	card_data = new_card_data
	caption_text = new_caption_text
	if is_node_ready():
		_apply_content()


func set_card_data(new_card_data: CardData) -> void:
	card_data = new_card_data
	if is_node_ready():
		_apply_content()


func set_caption_text(new_caption_text: String) -> void:
	caption_text = new_caption_text
	if is_node_ready():
		_apply_content()


func set_button_minimum_size(new_size: Vector2) -> void:
	button_minimum_size = new_size
	if is_node_ready():
		_apply_layout()


func set_card_size(new_size: Vector2) -> void:
	card_size = new_size
	if is_node_ready():
		_apply_layout()


#func set_label_min_height(new_height: int) -> void:
	#label_min_height = maxi(new_height, 0)
	#if is_node_ready():
		#_apply_layout()
#
#
#func set_content_separation(new_separation: int) -> void:
	#content_separation = maxi(new_separation, 0)
	#if is_node_ready():
		#_apply_layout()
#
#
#func set_label_font_size(new_font_size: int) -> void:
	#label_font_size = maxi(new_font_size, 1)
	#if is_node_ready():
		#_apply_layout()
#
#
#func set_content_margin_left(new_margin: int) -> void:
	#content_margin_left = maxi(new_margin, 0)
	#if is_node_ready():
		#_apply_layout()
#
#
#func set_content_margin_top(new_margin: int) -> void:
	#content_margin_top = maxi(new_margin, 0)
	#if is_node_ready():
		#_apply_layout()
#
#
#func set_content_margin_right(new_margin: int) -> void:
	#content_margin_right = maxi(new_margin, 0)
	#if is_node_ready():
		#_apply_layout()
#
#
#func set_content_margin_bottom(new_margin: int) -> void:
	#content_margin_bottom = maxi(new_margin, 0)
	#if is_node_ready():
		#_apply_layout()


func _apply_layout() -> void:
	custom_minimum_size = button_minimum_size
	card_wrapper.custom_minimum_size = card_size
	#caption_label.custom_minimum_size = Vector2(0, label_min_height)
	#caption_label.add_theme_font_size_override("font_size", label_font_size)
	#content.add_theme_constant_override("separation", content_separation)
	#margin_container.add_theme_constant_override("margin_left", content_margin_left)
	#margin_container.add_theme_constant_override("margin_top", content_margin_top)
	#margin_container.add_theme_constant_override("margin_right", content_margin_right)
	#margin_container.add_theme_constant_override("margin_bottom", content_margin_bottom)


func _apply_content() -> void:
	caption_label.text = caption_text
	if card_data != null:
		menu_card.set_card_data(card_data)


func _set_mouse_passthrough(node: Node) -> void:
	if node == null:
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough(child)
