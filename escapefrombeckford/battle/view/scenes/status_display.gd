# status_display.gd

class_name StatusDisplay extends Control

@export var status: Status : set = _set_status

@onready var icon: TextureRect = $Icon
@onready var stacks: Label = $Stacks

var _icon_size: float = 50.0
var intensity: int = 0
var turns_duration: int = 0
var pending: bool = false
var status_parent: CombatantView : set = _set_status_parent
var _pending_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_icon_layout()
	_refresh_display()

func _exit_tree() -> void:
	Events.tooltip_source_exited.emit(self)

func _set_status(new_status: Status) -> void:
	status = new_status
	if !is_node_ready():
		return
	_refresh_display()

func set_icon_size(new_icon_size: float) -> void:
	_icon_size = maxf(new_icon_size, 1.0)
	if !is_node_ready():
		return

	_apply_icon_layout()
	_refresh_display()

func set_status_state(new_status: Status, new_intensity: int, new_duration: int, new_pending := false) -> void:
	status = new_status
	intensity = maxi(int(new_intensity), 0)
	turns_duration = maxi(int(new_duration), 0)
	pending = bool(new_pending)
	if !is_node_ready():
		return
	_refresh_display()

func _refresh_display() -> void:
	if !is_node_ready():
		return

	_apply_icon_layout()
	if status == null:
		icon.texture = null
		stacks.visible = false
		return

	icon.texture = status.icon
	stacks.visible = status.number_display_type != Status.NumberDisplayType.NONE

	if status.number_display_type == Status.NumberDisplayType.DURATION:
		stacks.text = str(turns_duration)
	elif status.number_display_type == Status.NumberDisplayType.INTENSITY:
		stacks.text = str(intensity)

	_position_stacks()

	_refresh_pending_pulse()

func _apply_icon_layout() -> void:
	var icon_extent := Vector2(_icon_size, _icon_size)
	custom_minimum_size = icon_extent
	size = icon_extent
	icon.position = Vector2.ZERO
	icon.custom_minimum_size = icon_extent
	icon.size = icon_extent

func _position_stacks() -> void:
	if !stacks.visible:
		return

	stacks.reset_size()
	var stack_size := stacks.get_combined_minimum_size()
	stacks.size = stack_size
	var padding := Vector2(2.0, 0.0)
	stacks.position = Vector2(
		maxf(_icon_size - stack_size.x - padding.x, 0.0),
		maxf(_icon_size - stack_size.y - padding.y, 0.0)
	)

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

func _on_mouse_entered() -> void:
	if status == null:
		return

	Events.tooltip_source_entered.emit(self, _build_tooltip_request())

func _on_mouse_exited() -> void:
	Events.tooltip_source_exited.emit(self)

func _build_tooltip_request() -> TooltipRequest:
	var request := TooltipRequest.new()
	request.anchor_control = self
	request.anchor_rect = get_global_rect()
	request.icon_uid = status.icon.resource_path if status.icon != null else ""
	request.text_bbcode = status.get_tooltip(intensity, turns_duration)
	request.preferred_side = TooltipRequest.PreferredSide.ABOVE
	return request
