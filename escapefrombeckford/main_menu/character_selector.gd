extends Control

const DEFAULT_PROFILE_ID := "cole"

@export var player_catalog: PlayerCatalog = preload("uid://b2ewfy12rhm0l")

@onready var title: Label = %Title
@onready var description: Label = %Description
@onready var character_image: TextureRect = %CharacterImage

var current_profile_id: String = ""
var current_character: PlayerData : set = set_current_character

func _ready() -> void:
	if player_catalog != null:
		player_catalog.build_index()
	_set_current_profile(DEFAULT_PROFILE_ID)
	
func set_current_character(new_character: PlayerData) -> void:
	current_character = new_character
	if current_character == null:
		return
	title.text = current_character.name
	description.text = current_character.description
	character_image.texture = current_character.load_portrait_art()

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

func _on_start_button_pressed() -> void:
	if current_character == null:
		return
	#print("Start new escape attempt with %s" % current_character.name)
	var profile := RunProfile.new()
	profile.start_mode = RunProfile.StartMode.NEW_RUN
	profile.seed = 0
	profile.selected_starting_soul_uid = ""
	profile.player_profile_id = current_profile_id
	Autoload.begin_new_run(profile)


func _on_cole_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)


func _on_char_2_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)

func _on_char_3_button_pressed() -> void:
	_set_current_profile(DEFAULT_PROFILE_ID)
