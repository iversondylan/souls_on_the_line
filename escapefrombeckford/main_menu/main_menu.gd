extends Control

const CHAR_SELECTOR_SCENE := preload("uid://ba6ifh3shnl1d")
const RUN_SAVE_PICKER_SCN := preload("res://ui/run_save_picker.tscn")
const SAVE_NAME_DIALOG_SCN := preload("res://ui/save_name_dialog.tscn")
const CONFIRMATION_PROMPT_SCN := preload("res://ui/confirmation_prompt.tscn")

enum PickerContext {
	NONE,
	DEBUG_LOAD,
	PROFILE_SELECT,
	PROFILE_DELETE,
}

enum NamingContext {
	NONE,
	PROFILE_CREATE,
}

enum MainMenuView {
	PROFILE_HUB,
	PROFILE,
	SETTINGS,
}

@onready var profile_hub_menu: VBoxContainer = %ProfileHubMenu
@onready var profile_menu: VBoxContainer = %ProfileMenu
@onready var settings_menu: VBoxContainer = %SettingsMenu
@onready var choose_profile_button: Button = %ChooseProfile
@onready var create_profile_button: Button = %CreateProfile
@onready var debug_mode_toggle: CheckButton = %DebugModeToggle
@onready var current_profile_label: Label = %CurrentProfileLabel
@onready var continue_button: Button = %Continue
@onready var load_game_button: Button = %LoadGame
@onready var settings_profile_label: Label = %SettingsProfileLabel
@onready var delete_profile_button: Button = %DeleteProfile

var run_save_picker: RunSavePicker
var save_name_dialog: SaveNameDialog
var delete_profile_confirm_dialog
var picker_context: PickerContext = PickerContext.NONE
var naming_context: NamingContext = NamingContext.NONE
var current_view: MainMenuView = MainMenuView.PROFILE_HUB
var settings_return_view: MainMenuView = MainMenuView.PROFILE_HUB
var pending_delete_profile_key: String = ""
var pending_delete_profile_name: String = ""


func _ready() -> void:
	get_tree().paused = false
	SaveService.load_or_create_app_state()
	_ensure_dialogs()
	current_view = MainMenuView.PROFILE if SaveService.has_active_user_profile() else MainMenuView.PROFILE_HUB
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
	_hide_overlays()
	settings_return_view = MainMenuView.PROFILE_HUB
	current_view = MainMenuView.SETTINGS
	_refresh_menu_state()


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
	_hide_overlays()
	settings_return_view = MainMenuView.PROFILE
	current_view = MainMenuView.SETTINGS
	_refresh_menu_state()


func _on_settings_back_pressed() -> void:
	_hide_overlays()
	if settings_return_view == MainMenuView.PROFILE and SaveService.has_active_user_profile():
		current_view = MainMenuView.PROFILE
	else:
		current_view = MainMenuView.PROFILE_HUB
	_refresh_menu_state()


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
	_build_delete_profile_confirm_dialog()


func _refresh_menu_state() -> void:
	var active_profile_info := SaveService.get_active_user_profile_info()
	var has_active_profile := active_profile_info != null
	var debug_enabled := Autoload.is_debug_mode_enabled()
	var has_any_profiles := !SaveService.list_user_profiles().is_empty()

	if current_view == MainMenuView.PROFILE and !has_active_profile:
		current_view = MainMenuView.PROFILE_HUB
	if settings_return_view == MainMenuView.PROFILE and !has_active_profile:
		settings_return_view = MainMenuView.PROFILE_HUB

	profile_hub_menu.visible = current_view == MainMenuView.PROFILE_HUB
	profile_menu.visible = current_view == MainMenuView.PROFILE
	settings_menu.visible = current_view == MainMenuView.SETTINGS
	debug_mode_toggle.visible = has_active_profile
	debug_mode_toggle.set_pressed_no_signal(debug_enabled)

	if has_active_profile:
		current_profile_label.text = "Profile: %s" % active_profile_info.display_name
		continue_button.disabled = !SaveService.has_active_run()
		load_game_button.visible = debug_enabled
		load_game_button.disabled = !debug_enabled or SaveService.list_debug_run_saves().is_empty()
		settings_profile_label.text = "Active profile: %s" % String(active_profile_info.display_name)
	else:
		choose_profile_button.disabled = !has_any_profiles
		settings_profile_label.text = "No active profile selected."

	delete_profile_button.disabled = !has_any_profiles

	if !debug_enabled and picker_context == PickerContext.DEBUG_LOAD:
		_hide_overlays()


func _hide_overlays() -> void:
	picker_context = PickerContext.NONE
	naming_context = NamingContext.NONE
	if run_save_picker != null:
		run_save_picker.hide_picker()
	if save_name_dialog != null:
		save_name_dialog.hide_dialog()
	if delete_profile_confirm_dialog != null:
		delete_profile_confirm_dialog.hide_prompt()
	_clear_pending_delete_profile()


func _on_picker_entry_selected(entry_key: String) -> void:
	match picker_context:
		PickerContext.DEBUG_LOAD:
			Autoload.begin_load_debug_run(entry_key)
		PickerContext.PROFILE_SELECT:
			if Autoload.set_active_user_profile(entry_key):
				current_view = MainMenuView.PROFILE
				_refresh_menu_state()
		PickerContext.PROFILE_DELETE:
			_open_delete_profile_confirmation(entry_key)
	picker_context = PickerContext.NONE


func _on_picker_closed() -> void:
	picker_context = PickerContext.NONE


func _on_name_submitted(value: String) -> void:
	match naming_context:
		NamingContext.PROFILE_CREATE:
			var created := SaveService.create_user_profile(value)
			if created != null and Autoload.set_active_user_profile(String(created.profile_key)):
				current_view = MainMenuView.PROFILE
				_refresh_menu_state()
	naming_context = NamingContext.NONE


func _on_naming_closed() -> void:
	naming_context = NamingContext.NONE


func _build_delete_profile_confirm_dialog() -> void:
	delete_profile_confirm_dialog = CONFIRMATION_PROMPT_SCN.instantiate()
	if delete_profile_confirm_dialog == null:
		return
	delete_profile_confirm_dialog.canceled.connect(_clear_pending_delete_profile)
	delete_profile_confirm_dialog.confirmed.connect(_confirm_delete_profile)
	add_child(delete_profile_confirm_dialog)


func _on_delete_profile_pressed() -> void:
	if delete_profile_button.disabled or run_save_picker == null:
		return
	picker_context = PickerContext.PROFILE_DELETE
	run_save_picker.show_profiles("Delete Profile", SaveService.list_user_profiles())


func _confirm_delete_profile() -> void:
	if pending_delete_profile_key.is_empty():
		return
	var deleted_active_profile := pending_delete_profile_key == SaveService.get_active_user_profile_key()
	if !SaveService.delete_user_profile(pending_delete_profile_key):
		return
	_hide_overlays()
	if deleted_active_profile or !SaveService.has_active_user_profile():
		current_view = MainMenuView.PROFILE_HUB
		settings_return_view = MainMenuView.PROFILE_HUB
	_refresh_menu_state()


func _open_delete_profile_confirmation(profile_key: String) -> void:
	if delete_profile_confirm_dialog == null:
		return
	var profile_info := SaveService.get_user_profile_info(profile_key)
	if profile_info == null:
		return
	pending_delete_profile_key = profile_key
	pending_delete_profile_name = String(profile_info.display_name)
	delete_profile_confirm_dialog.open(
		"Delete profile \"%s\" and all of its saves?" % pending_delete_profile_name,
		"Delete",
		"Cancel"
	)


func _clear_pending_delete_profile() -> void:
	pending_delete_profile_key = ""
	pending_delete_profile_name = ""
