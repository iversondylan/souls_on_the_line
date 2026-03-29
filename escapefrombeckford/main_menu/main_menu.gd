extends Control

const CHAR_SELECTOR_SCENE := preload("uid://ba6ifh3shnl1d")
const RUN_SAVE_PICKER_SCN := preload("res://ui/run_save_picker.tscn")
const SAVE_NAME_DIALOG_SCN := preload("res://ui/save_name_dialog.tscn")

enum PickerContext {
	NONE,
	DEBUG_LOAD,
	PROFILE_SELECT,
}

enum NamingContext {
	NONE,
	PROFILE_CREATE,
}

@onready var profile_hub_menu: VBoxContainer = %ProfileHubMenu
@onready var profile_menu: VBoxContainer = %ProfileMenu
@onready var choose_profile_button: Button = %ChooseProfile
@onready var create_profile_button: Button = %CreateProfile
@onready var debug_mode_toggle: CheckButton = %DebugModeToggle
@onready var current_profile_label: Label = %CurrentProfileLabel
@onready var continue_button: Button = %Continue
@onready var load_game_button: Button = %LoadGame

var run_save_picker: RunSavePicker
var save_name_dialog: SaveNameDialog
var picker_context: PickerContext = PickerContext.NONE
var naming_context: NamingContext = NamingContext.NONE


func _ready() -> void:
	get_tree().paused = false
	SaveService.load_or_create_app_state()
	_ensure_dialogs()
	_refresh_menu_state()


func _on_choose_profile_pressed() -> void:
	picker_context = PickerContext.PROFILE_SELECT
	run_save_picker.show_profiles("Choose Profile", SaveService.list_user_profiles())


func _on_create_profile_pressed() -> void:
	naming_context = NamingContext.PROFILE_CREATE
	var existing_profile_keys := PackedStringArray()
	for info in SaveService.list_user_profiles():
		existing_profile_keys.append(String(info.profile_key))
	save_name_dialog.open(
		existing_profile_keys,
		"",
		"Create Profile",
		"Create Profile",
		"Create Profile",
		"A profile with this name already exists.",
		false,
		Callable(SaveService, "user_profile_key_from_name")
	)


func _on_hub_settings_pressed() -> void:
	pass


func _on_debug_mode_toggled(enabled: bool) -> void:
	Autoload.set_debug_mode_enabled(enabled)
	_refresh_menu_state()


func _on_continue_pressed() -> void:
	Autoload.begin_continue_run()


func _on_load_game_pressed() -> void:
	picker_context = PickerContext.DEBUG_LOAD
	run_save_picker.show_slots("Load Debug Save", SaveService.list_debug_run_saves())


func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)


func _on_back_pressed() -> void:
	_hide_overlays()
	Autoload.clear_active_user_profile()
	_refresh_menu_state()


func _on_profile_settings_pressed() -> void:
	pass


func _on_exit_pressed() -> void:
	get_tree().quit()


func _ensure_dialogs() -> void:
	run_save_picker = RUN_SAVE_PICKER_SCN.instantiate() as RunSavePicker
	save_name_dialog = SAVE_NAME_DIALOG_SCN.instantiate() as SaveNameDialog
	if run_save_picker != null:
		add_child(run_save_picker)
		run_save_picker.entry_selected.connect(_on_picker_entry_selected)
		run_save_picker.canceled.connect(_on_picker_closed)
	if save_name_dialog != null:
		add_child(save_name_dialog)
		save_name_dialog.save_requested.connect(_on_name_submitted)
		save_name_dialog.canceled.connect(_on_naming_closed)


func _refresh_menu_state() -> void:
	var active_profile_info := SaveService.get_active_user_profile_info()
	var has_active_profile := active_profile_info != null
	var debug_enabled := Autoload.is_debug_mode_enabled()

	profile_hub_menu.visible = !has_active_profile
	profile_menu.visible = has_active_profile
	debug_mode_toggle.visible = has_active_profile
	debug_mode_toggle.set_pressed_no_signal(debug_enabled)

	if has_active_profile:
		current_profile_label.text = "Profile: %s" % active_profile_info.display_name
		continue_button.disabled = !SaveService.has_active_run()
		load_game_button.visible = debug_enabled
		load_game_button.disabled = !debug_enabled or SaveService.list_debug_run_saves().is_empty()
	else:
		choose_profile_button.disabled = SaveService.list_user_profiles().is_empty()

	if !debug_enabled and picker_context == PickerContext.DEBUG_LOAD:
		_hide_overlays()


func _hide_overlays() -> void:
	picker_context = PickerContext.NONE
	naming_context = NamingContext.NONE
	if run_save_picker != null:
		run_save_picker.hide_picker()
	if save_name_dialog != null:
		save_name_dialog.hide_dialog()


func _on_picker_entry_selected(entry_key: String) -> void:
	match picker_context:
		PickerContext.DEBUG_LOAD:
			Autoload.begin_load_debug_run(entry_key)
		PickerContext.PROFILE_SELECT:
			if Autoload.set_active_user_profile(entry_key):
				_refresh_menu_state()
	picker_context = PickerContext.NONE


func _on_picker_closed() -> void:
	picker_context = PickerContext.NONE


func _on_name_submitted(value: String) -> void:
	match naming_context:
		NamingContext.PROFILE_CREATE:
			var created := SaveService.create_user_profile(value)
			if created != null and Autoload.set_active_user_profile(String(created.profile_key)):
				_refresh_menu_state()
	naming_context = NamingContext.NONE


func _on_naming_closed() -> void:
	naming_context = NamingContext.NONE
