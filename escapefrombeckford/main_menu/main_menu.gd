extends Control

const CHAR_SELECTOR_SCENE := preload("uid://ba6ifh3shnl1d")

@onready var continue_button: Button = %Continue


func _ready() -> void:
	get_tree().paused = false
	SaveService.load_or_create_profile()
	continue_button.disabled = !SaveService.has_active_run()


func _on_continue_pressed() -> void:
	Autoload.begin_continue_run()

func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()
