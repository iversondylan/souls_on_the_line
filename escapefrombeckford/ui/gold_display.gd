class_name GoldDisplay extends HBoxContainer

@export var run_state: RunState : set = set_run_state

@onready var label: Label = $Label

func _ready() -> void:
	label.text = "0"

func set_run_state(new_state: RunState) -> void:
	run_state = new_state
	if run_state != null and !run_state.gold_changed.is_connected(_update_gold):
		run_state.gold_changed.connect(_update_gold)
		_update_gold()

func _update_gold() -> void:
	label.text = str(run_state.gold) if run_state != null else "0"
	
