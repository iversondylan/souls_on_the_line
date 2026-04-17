class_name CardSelectionOverlay extends ColorRect

signal selection_confirmed(card_data: CardData)
signal selection_canceled()

const MENU_CARD := preload("uid://d4g7iin5x7648")
const BUTTON_STYLE_PANEL_THEME := preload("res://ui/elements/button_style_panel_theme.tres")

@onready var title_label: Label = %Title
@onready var card_choice_container: HBoxContainer = %CardChoiceContainer
@onready var no_cards_label: Label = %NoCardsLabel
@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton

var card_choices: Array[CardData] = []
var card_filter: Callable
var max_cards_to_show: int = 5
var selected_card: CardData = null
var _card_wrappers_by_uid: Dictionary = {}


func _ready() -> void:
	cancel_button.pressed.connect(
		func() -> void:
			selection_canceled.emit()
			queue_free()
	)
	confirm_button.pressed.connect(_confirm_selection)
	_refresh()


func configure(
	choices: Array[CardData],
	new_title: String,
	new_confirm_text: String = "Confirm",
	new_cancel_text: String = "Cancel",
	new_filter: Callable = Callable(),
	new_max_cards_to_show: int = 5
) -> void:
	if !is_node_ready():
		await ready
	card_filter = new_filter
	max_cards_to_show = maxi(int(new_max_cards_to_show), 0)
	title_label.text = new_title
	confirm_button.text = new_confirm_text
	cancel_button.text = new_cancel_text
	card_choices = _filtered_choices(choices)
	_refresh()


func _filtered_choices(choices: Array[CardData]) -> Array[CardData]:
	var filtered: Array[CardData] = []
	for card_data in choices:
		if card_data == null:
			continue
		if card_filter.is_valid() and !bool(card_filter.call(card_data)):
			continue
		filtered.append(card_data)
		if max_cards_to_show > 0 and filtered.size() >= max_cards_to_show:
			break
	return filtered


func _refresh() -> void:
	if !is_node_ready():
		return
	for child in card_choice_container.get_children():
		child.queue_free()
	_card_wrappers_by_uid.clear()
	selected_card = null

	no_cards_label.visible = card_choices.is_empty()
	for card_data in card_choices:
		var wrapper := Button.new()
		wrapper.theme = BUTTON_STYLE_PANEL_THEME
		wrapper.custom_minimum_size = Vector2(275, 370)
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		wrapper.pressed.connect(_on_card_chosen.bind(card_data))
		card_choice_container.add_child(wrapper)
		wrapper.self_modulate = Color(0.72, 0.72, 0.72, 1.0)

		var menu_card := MENU_CARD.instantiate() as MenuCard
		menu_card.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu_card.offset_left = 0.0
		menu_card.offset_top = 0.0
		menu_card.offset_right = 0.0
		menu_card.offset_bottom = 0.0
		wrapper.add_child(menu_card)
		menu_card.set_card_data(card_data)
		_set_mouse_passthrough(menu_card)
		card_data.ensure_uid()
		_card_wrappers_by_uid[String(card_data.uid)] = wrapper

	confirm_button.disabled = true


func _on_card_chosen(card_data: CardData) -> void:
	if card_data == null:
		return
	selected_card = card_data
	_refresh_selection_highlight()
	confirm_button.disabled = false


func _refresh_selection_highlight() -> void:
	var selected_uid := ""
	if selected_card != null:
		selected_card.ensure_uid()
		selected_uid = String(selected_card.uid)

	for uid in _card_wrappers_by_uid.keys():
		var wrapper := _card_wrappers_by_uid.get(uid, null) as CanvasItem
		if wrapper == null:
			continue
		wrapper.self_modulate = Color.WHITE if uid == selected_uid else Color(0.72, 0.72, 0.72, 1.0)


func _confirm_selection() -> void:
	if selected_card == null:
		return
	selection_confirmed.emit(selected_card)
	queue_free()


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough(child)
