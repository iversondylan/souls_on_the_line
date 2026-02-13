# battle_ui.gd

class_name BattleUI extends CanvasLayer

@onready var end_turn: Button = $EndTurn
@onready var summon_replace_prompt: Node2D = $SelectionPrompt

func _ready() -> void:
	Events.discard_selection_started.connect(_on_discard_selection_started)
	Events.discard_finished.connect(_on_discard_finished)

func _on_discard_selection_started(_ctx: DiscardContext) -> void:
	set_end_turn_enabled(false)

func _on_discard_finished(_ctx: DiscardContext) -> void:
	set_end_turn_enabled(true)

func set_end_turn_enabled(enabled: bool) -> void:
	if enabled:
		end_turn.disabled = false
	else:
		end_turn.disabled = true

func show_summon_replace_prompt(show: bool) -> void:
	if show:
		summon_replace_prompt.show_prompt("Choose an ally to [b]fade[/b].")
	else:
		summon_replace_prompt.hide_prompt()
