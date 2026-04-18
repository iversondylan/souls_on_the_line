# status_display.gd

class_name StatusDisplay extends Control

@export var status: Status : set = _set_status

@onready var icon: TextureRect = $Icon
@onready var stacks: Label = $Stacks

var intensity: int = 0
var turns_duration: int = 0
var pending: bool = false
var status_parent: CombatantView : set = _set_status_parent
var _pending_tween: Tween = null

func _ready() -> void:
	_refresh_display()

func _set_status(new_status: Status) -> void:
	if !is_node_ready():
		await ready

	status = new_status
	_refresh_display()

func set_status_state(new_status: Status, new_intensity: int, new_duration: int, new_pending := false) -> void:
	if !is_node_ready():
		await ready

	status = new_status
	intensity = maxi(int(new_intensity), 0)
	turns_duration = maxi(int(new_duration), 0)
	pending = bool(new_pending)
	_refresh_display()

func _refresh_display() -> void:
	if status == null or !is_node_ready():
		return

	icon.texture = status.icon
	stacks.visible = status.number_display_type != Status.NumberDisplayType.NONE
	custom_minimum_size = icon.size

	if status.number_display_type == Status.NumberDisplayType.DURATION:
		stacks.text = str(turns_duration)
	elif status.number_display_type == Status.NumberDisplayType.INTENSITY:
		stacks.text = str(intensity)
	else:
		stacks.text = ""

	if stacks.visible:
		custom_minimum_size = stacks.size + stacks.position

	_refresh_pending_pulse()

func _refresh_pending_pulse() -> void:
	if _pending_tween != null and is_instance_valid(_pending_tween):
		_pending_tween.kill()
	_pending_tween = null

	if !pending:
		modulate.a = 1.0
		return

	modulate.a = 1.0
	_pending_tween = create_tween()
	_pending_tween.set_loops()
	_pending_tween.tween_property(self, "modulate:a", 0.45, 0.45)
	_pending_tween.tween_property(self, "modulate:a", 1.0, 0.45)

func _set_status_parent(new_status_parent: CombatantView) -> void:
	status_parent = new_status_parent
	if status != null:
		status.status_parent = status_parent

func _on_icon_mouse_entered() -> void:
	if status == null:
		return

	var request := TooltipRequest.new()
	request.anchor_rect = icon.get_global_rect()
	request.icon_uid = status.icon.resource_path if status.icon != null else ""
	request.text_bbcode = status.get_tooltip(intensity, turns_duration)
	request.preferred_side = TooltipRequest.PreferredSide.ABOVE
	Events.tooltip_show_requested.emit(request)

func _on_icon_mouse_exited() -> void:
	Events.tooltip_hide_requested.emit()
