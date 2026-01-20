# battle_ui.gd

class_name BattleUI extends Node2D

@onready var end_turn: Button = $EndTurn
@onready var summon_replace_prompt: Node2D = $SummonReplacePrompt

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
