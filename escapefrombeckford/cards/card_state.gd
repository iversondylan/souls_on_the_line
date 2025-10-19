class_name CardState extends Node

var player: Player

enum State {
	BASE,
	CLICKED,
	DRAGGING,
	AIMING,
	RELEASED
}

signal transition_requested(from: CardState, to: State)

@export var state: State

var usable_card: UsableCard

func enter() -> void:
	pass

func dwell() -> void:
	pass

func exit() -> void:
	pass

func on_input(_event: InputEvent) -> void:
	pass

func on_gui_input(_event: InputEvent) -> void:
	pass

func on_mouse_entered() -> void:
	pass

func on_mouse_exited() -> void:
	pass
