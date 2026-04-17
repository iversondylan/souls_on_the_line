extends Control

const DEFAULT_PROFILE_ID := "cole"
const MAIN_MENU_SCENE_PATH := "res://main_menu/main_menu.tscn"
const SOUL_SLOT_BUTTON := preload("res://ui/soul_slot_button.tscn")

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
	character_image.texture = current_character.load_character_art()


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
		_refresh_soul_buttons()
		return
	var profile := player_catalog.get_profile(profile_id)
	if profile == null:
		profile = player_catalog.get_default_profile()
		if profile != null:
			current_profile_id = String(profile.profile_id)
	set_current_character(profile)
	_refresh_soul_buttons()


func _refresh_soul_buttons() -> void:
	for child in soul_buttons.get_children():
		child.queue_free()

	var soul_options := _get_signature_soul_options()
	if soul_options.is_empty():
		soul_title.visible = false
		soul_buttons.visible = false
		return

	soul_title.visible = true
	soul_buttons.visible = true

	for option in soul_options:
		var card_data := option.get("card", null) as CardData
		var selection_uid := String(option.get("selection_uid", ""))
		var slot_label := String(option.get("slot_label", ""))
		_add_soul_button(card_data, selection_uid, slot_label, selection_uid == selected_starting_soul_uid)

	if _soul_button_group.get_pressed_button() == null and soul_buttons.get_child_count() > 0:
		var first_button := soul_buttons.get_child(0) as Button
		if first_button != null:
			first_button.button_pressed = true
			_on_soul_button_pressed(String(first_button.get_meta("card_uid", "")))


func _add_soul_button(card_data: CardData, card_uid: String, slot_label: String, is_selected: bool) -> void:
	if card_data == null:
		return
	var button := SOUL_SLOT_BUTTON.instantiate() as Button
	button.toggle_mode = true
	button.button_group = _soul_button_group
	button.button_pressed = is_selected
	button.set_meta("card_uid", card_uid)
	button.pressed.connect(_on_soul_button_pressed.bind(card_uid))
	button.set("card_data", card_data)
	button.set("caption_text", slot_label)
	soul_buttons.add_child(button)


func _get_current_starter_soul() -> CardData:
	if current_character == null:
		return null
	return current_character.starter_soul


func _get_signature_soul_options() -> Array:
	var starter_soul := _get_current_starter_soul()
	if starter_soul == null:
		return []
	if profile_data == null or profile_data.soul_recess_state == null:
		return [{
			"selection_uid": "",
			"slot_index": -1,
			"slot_label": SoulRecessState.DEFAULT_SOUL_SLOT_LABEL,
			"card": starter_soul.make_runtime_instance(),
		}]
	return profile_data.soul_recess_state.build_signature_soul_options(starter_soul)


func _get_selected_signature_soul_card() -> CardData:
	for option in _get_signature_soul_options():
		if String(option.get("selection_uid", "")) != selected_starting_soul_uid:
			continue
		return option.get("card", null) as CardData
	var starter_soul := _get_current_starter_soul()
	return starter_soul.make_runtime_instance() if starter_soul != null else null


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


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _begin_run(start_mode: RunProfile.StartMode) -> void:
	if current_character == null:
		return
	var profile := RunProfile.new()
	profile.start_mode = start_mode
	profile.has_soulbound_roster = start_mode != RunProfile.StartMode.TUTORIAL
	profile.seed = 0
	profile.selected_starting_soul_uid = selected_starting_soul_uid
	profile.player_profile_id = current_profile_id
	profile.set_selected_signature_soul(_get_selected_signature_soul_card())
	Autoload.begin_new_run(profile)


func _on_cole_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)


func _on_char_2_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)


func _on_char_3_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)
