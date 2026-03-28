extends Control

const CHAR_SELECTOR_SCENE := preload("res://main_menu/character_selector.tscn")
const RUN_SCENE := preload("res://run/flow/run.tscn")

@export var run_startup: RunStartup = preload("res://run/flow/run_startup.tres")

@onready var continue_button: Button = %Continue


func _ready() -> void:
	get_tree().paused = false
	SaveService.load_or_create_profile()
	continue_button.disabled = !SaveService.has_active_run()


func _on_continue_pressed() -> void:
	run_startup.startup_type = RunStartup.StartupType.CONTINUED_RUN
	get_tree().change_scene_to_packed(RUN_SCENE)

func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()
