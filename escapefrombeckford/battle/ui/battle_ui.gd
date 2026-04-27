# battle_ui.gd

class_name BattleUI extends CanvasLayer

@onready var end_turn: Button = $EndTurn
@onready var summon_replace_prompt: Control = $SelectionPrompt

var _requested_enabled: bool = false
var _discard_modal_active: bool = false
var _cleanup_active: bool = false

func _ready() -> void:
	Events.discard_selection_started.connect(_on_discard_selection_started)
	Events.discard_finished.connect(_on_discard_finished)
	Events.player_end_cleanup_started.connect(_on_player_end_cleanup_started)
	Events.player_end_cleanup_completed.connect(_on_player_end_cleanup_completed)

func _on_discard_selection_started(_ctx: DiscardContext) -> void:
	_discard_modal_active = true
	_refresh_end_turn_enabled()

func _on_discard_finished(_ctx: DiscardContext) -> void:
	_discard_modal_active = false
	_refresh_end_turn_enabled()

func _on_player_end_cleanup_started(_ctx: HandCleanupContext) -> void:
	_cleanup_active = true
	_refresh_end_turn_enabled()

func _on_player_end_cleanup_completed(_ctx: HandCleanupContext) -> void:
	_cleanup_active = false
	_refresh_end_turn_enabled()

func set_end_turn_enabled(enabled: bool) -> void:
	_requested_enabled = enabled
	_refresh_end_turn_enabled()

func _refresh_end_turn_enabled() -> void:
	end_turn.disabled = !_requested_enabled or _discard_modal_active or _cleanup_active

func show_summon_replace_prompt(_show: bool) -> void:
	if _show:
		summon_replace_prompt.show_prompt("Choose an ally to [b]fade[/b].")
	else:
		summon_replace_prompt.hide_prompt()
