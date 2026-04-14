extends Control

const DEFAULT_PROFILE_ID := "cole"
const MENU_CARD := preload("uid://d4g7iin5x7648")

@export var player_catalog: PlayerCatalog = preload("uid://b2ewfy12rhm0l")

@onready var title: Label = %Title
@onready var description: Label = %Description
@onready var character_image: TextureRect = %CharacterImage
@onready var soul_title: Label = %SoulTitle
@onready var soul_buttons: HBoxContainer = %SoulButtons

var current_profile_id: String = ""
var current_character: PlayerData : set = set_current_character
var profile_data: ProfileData
var selected_starting_soul_uid: String = ""
var _soul_button_group := ButtonGroup.new()


func _ready() -> void:
	if player_catalog != null:
		player_catalog.build_index()
	_load_profile_data()
	_set_current_profile(DEFAULT_PROFILE_ID)
	_refresh_soul_buttons()


func set_current_character(new_character: PlayerData) -> void:
	current_character = new_character
	if current_character == null:
		return
	title.text = current_character.name
	description.text = current_character.description
	character_image.texture = current_character.load_portrait_art()


func _load_profile_data() -> void:
	profile_data = SaveService.load_or_create_profile()
	if profile_data == null or profile_data.soul_recess_state == null:
		selected_starting_soul_uid = ""
		return
	selected_starting_soul_uid = String(profile_data.soul_recess_state.selected_starting_soul_uid)


func _set_current_profile(profile_id: String) -> void:
	current_profile_id = profile_id
	if player_catalog == null:
		current_character = null
		return
	var profile := player_catalog.get_profile(profile_id)
	if profile == null:
		profile = player_catalog.get_default_profile()
		if profile != null:
			current_profile_id = String(profile.profile_id)
	set_current_character(profile)


func _refresh_soul_buttons() -> void:
	for child in soul_buttons.get_children():
		child.queue_free()

	if profile_data == null or profile_data.soul_recess_state == null:
		soul_title.visible = false
		soul_buttons.visible = false
		return

	soul_title.visible = true
	soul_buttons.visible = true

	var recess := profile_data.soul_recess_state
	var visible_slots := mini(recess.attuned_souls.size(), maxi(int(recess.unlocked_slot_count), 0))
	for slot_index in range(visible_slots):
		var snapshot := recess.get_attuned_soul_snapshot_at(slot_index)
		if snapshot == null:
			continue
		var card_data := snapshot.instantiate_card()
		if card_data == null:
			continue
		card_data.ensure_uid()

		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 320)
		button.toggle_mode = true
		button.button_group = _soul_button_group
		button.button_pressed = String(card_data.uid) == selected_starting_soul_uid
		button.set_meta("card_uid", String(card_data.uid))
		button.pressed.connect(_on_soul_button_pressed.bind(String(card_data.uid)))
		soul_buttons.add_child(button)

		var menu_card := MENU_CARD.instantiate() as MenuCard
		button.add_child(menu_card)
		menu_card.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu_card.offset_left = 0.0
		menu_card.offset_top = 0.0
		menu_card.offset_right = 0.0
		menu_card.offset_bottom = 0.0
		menu_card.set_card_data(card_data)
		_set_mouse_passthrough(menu_card)

	if _soul_button_group.get_pressed_button() == null and soul_buttons.get_child_count() > 0:
		var first_button := soul_buttons.get_child(0) as Button
		if first_button != null:
			first_button.button_pressed = true
			_on_soul_button_pressed(String(first_button.get_meta("card_uid", "")))


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough(child)


func _on_soul_button_pressed(card_uid: String) -> void:
	selected_starting_soul_uid = card_uid
	if profile_data == null or profile_data.soul_recess_state == null:
		return
	profile_data.soul_recess_state.selected_starting_soul_uid = selected_starting_soul_uid
	SaveService.save_profile(profile_data)


func _on_start_button_pressed() -> void:
	_begin_run(RunProfile.StartMode.NEW_RUN)


func _on_tutorial_button_pressed() -> void:
	_begin_run(RunProfile.StartMode.TUTORIAL)


func _begin_run(start_mode: RunProfile.StartMode) -> void:
	if current_character == null:
		return
	var profile := RunProfile.new()
	profile.start_mode = start_mode
	profile.seed = 0
	profile.selected_starting_soul_uid = selected_starting_soul_uid
	profile.player_profile_id = current_profile_id
	Autoload.begin_new_run(profile)


func _on_cole_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)


func _on_char_2_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)


func _on_char_3_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)
