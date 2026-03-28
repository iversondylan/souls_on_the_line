class_name BattleOverPanel extends Panel

enum Outcome {WIN, LOSE}

const MAIN_MENU_SCN := preload("uid://byfyjsj2j7wh")

@onready var label: Label = %Label
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton

func _ready() -> void:
	continue_button.pressed.connect(func(): Events.battle_won.emit())
	restart_button.pressed.connect(_return_to_main_menu)
	Events.battle_over_screen_requested.connect(show_screen)

func show_screen(text: String, outcome: Outcome) -> void:
	label.text = text
	continue_button.visible = outcome == Outcome.WIN
	restart_button.visible = outcome == Outcome.LOSE
	show()
	get_tree().paused = true


func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_packed(MAIN_MENU_SCN)
