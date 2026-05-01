class_name Tooltip extends Control

@export var fade_seconds: float = 0.2
@export var show_delay_seconds: float = 0.0
@export var hide_grace_seconds: float = 0.08

const MIN_PANEL_WIDTH := 220.0
const MAX_PANEL_WIDTH := 520.0
const VIEWPORT_WIDTH_RATIO := 0.4
const TEXT_PADDING_WIDTH := 120.0
const TEXT_WIDTH_PER_CHARACTER := 6.0
const CONTENT_MARGIN_TOTAL := 10.0

enum State {
	IDLE,
	PENDING_SHOW,
	VISIBLE,
	PENDING_HIDE,
}

@onready var tooltip_icon: TextureRect = %TooltipIcon
@onready var tooltip_description: RichTextLabel = %TooltipDescription
@onready var panel_container: PanelContainer = $PanelContainer

var tween: Tween
var _state: State = State.IDLE
var _hovered_sources: Dictionary = {}
var _source_enter_order: Dictionary = {}
var _enter_sequence: int = 0
var _active_source: Object = null
var _active_request: TooltipRequest = null
var _show_timer: Timer
var _hide_timer: Timer

func _ready() -> void:
	Events.tooltip_source_entered.connect(_on_tooltip_source_entered)
	Events.tooltip_source_exited.connect(_on_tooltip_source_exited)
	tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_description.fit_content = false
	modulate = Color.TRANSPARENT
	_show_timer = _create_timer(_on_show_timer_timeout)
	_hide_timer = _create_timer(_on_hide_timer_timeout)
	set_process(false)
	hide()

func _process(_delta: float) -> void:
	_prune_invalid_sources()

	if _state != State.VISIBLE:
		return

	if !_has_active_source():
		_refresh_winner()
		return

	_position_panel(_active_request)

func _on_tooltip_source_entered(source: Object, request: TooltipRequest) -> void:
	if source == null or request == null:
		return

	_prune_invalid_sources()
	_hovered_sources[source] = request
	_enter_sequence += 1
	_source_enter_order[source] = _enter_sequence
	_cancel_hide()
	_refresh_winner()

func _on_tooltip_source_exited(source: Object) -> void:
	if source != null:
		_unregister_source(source)
	_refresh_winner()

func _refresh_winner() -> void:
	_prune_invalid_sources()

	var winner := _get_winning_source()
	if winner == null:
		_begin_hide_grace()
		return

	var request := _hovered_sources[winner] as TooltipRequest
	_active_source = winner
	_active_request = request
	_cancel_hide()

	match _state:
		State.IDLE, State.PENDING_HIDE:
			_schedule_show()
		State.PENDING_SHOW:
			_schedule_show()
		State.VISIBLE:
			_present_active_request(true)

func _schedule_show() -> void:
	_cancel_show()
	if _active_request == null:
		return

	if show_delay_seconds <= 0.0:
		_present_active_request(false)
		return

	_state = State.PENDING_SHOW
	_show_timer.start(show_delay_seconds)

func _on_show_timer_timeout() -> void:
	if !_has_active_source():
		_refresh_winner()
		return

	_present_active_request(false)

func _begin_hide_grace() -> void:
	_cancel_show()
	if _state == State.IDLE:
		return

	if hide_grace_seconds <= 0.0:
		_hide_now()
		return

	_state = State.PENDING_HIDE
	_hide_timer.start(hide_grace_seconds)

func _on_hide_timer_timeout() -> void:
	_prune_invalid_sources()
	if _get_winning_source() != null:
		_refresh_winner()
		return

	_hide_now()

func _present_active_request(skip_fade: bool) -> void:
	if _active_request == null:
		return

	_cancel_show()
	_cancel_hide()
	_apply_request_content(_active_request)
	_state = State.VISIBLE
	set_process(true)

	if tween:
		tween.kill()

	show()
	if skip_fade or fade_seconds <= 0.0:
		modulate = Color.WHITE
		return

	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color.WHITE, fade_seconds)

func _position_panel(request: TooltipRequest) -> void:
	if request == null:
		return

	var viewport_rect := get_viewport_rect()
	var panel_size := panel_container.size
	var anchor_rect := _get_anchor_rect(request)
	if anchor_rect.size == Vector2.ZERO:
		return

	var margin := 12.0
	var x := anchor_rect.position.x + (anchor_rect.size.x - panel_size.x) * 0.5 + request.offset.x
	var below_y := anchor_rect.end.y + margin + request.offset.y
	var above_y := anchor_rect.position.y - panel_size.y - margin + request.offset.y
	var y := below_y

	if request.preferred_side == TooltipRequest.PreferredSide.ABOVE:
		y = above_y
		if y < viewport_rect.position.y:
			y = below_y
	elif below_y + panel_size.y > viewport_rect.end.y:
		y = above_y

	x = clampf(x, viewport_rect.position.x, viewport_rect.end.x - panel_size.x)
	y = clampf(y, viewport_rect.position.y, viewport_rect.end.y - panel_size.y)
	panel_container.position = Vector2(x, y)

func _apply_request_content(request: TooltipRequest) -> void:
	tooltip_icon.visible = !request.icon_uid.is_empty()
	tooltip_icon.texture = load(request.icon_uid) if tooltip_icon.visible else null
	_resize_panel(request)
	_position_panel(request)

func _resize_panel(request: TooltipRequest) -> void:
	var viewport_rect := get_viewport_rect()
	var max_panel_width := viewport_rect.size.x * VIEWPORT_WIDTH_RATIO
	if max_panel_width > MAX_PANEL_WIDTH:
		max_panel_width = MAX_PANEL_WIDTH
	var target_panel_width := clampf(_estimate_panel_width(request.text_bbcode), MIN_PANEL_WIDTH, max_panel_width)
	var panel_chrome := _get_panel_chrome_size()
	var target_text_width := maxf(target_panel_width - panel_chrome.x, 0.0)

	tooltip_icon.custom_minimum_size = Vector2(64, 64) if tooltip_icon.visible else Vector2.ZERO
	tooltip_description.clear()
	tooltip_description.custom_minimum_size = Vector2(target_text_width, 0.0)
	tooltip_description.size = Vector2(target_text_width, 0.0)
	tooltip_description.append_text(request.text_bbcode)
	tooltip_description.reset_size()
	panel_container.custom_minimum_size = Vector2.ZERO
	panel_container.reset_size()

	var text_height := tooltip_description.get_content_height()
	tooltip_description.custom_minimum_size = Vector2(target_text_width, ceilf(text_height))
	tooltip_description.size = Vector2(target_text_width, ceilf(text_height))
	var icon_height := tooltip_icon.custom_minimum_size.y if tooltip_icon.visible else 0.0
	var panel_height := panel_chrome.y + text_height + icon_height
	panel_container.size = Vector2(target_panel_width, ceilf(panel_height))

func _estimate_panel_width(text_bbcode: String) -> float:
	var plain_text := _strip_bbcode(text_bbcode)
	var longest_line := 0
	for line in plain_text.split("\n"):
		longest_line = maxi(longest_line, line.strip_edges().length())
	return TEXT_PADDING_WIDTH + float(longest_line) * TEXT_WIDTH_PER_CHARACTER

func _strip_bbcode(text_bbcode: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[[^\\]]+\\]")
	return regex.sub(text_bbcode, "", true)

func _get_panel_chrome_size() -> Vector2:
	var chrome := Vector2(CONTENT_MARGIN_TOTAL, CONTENT_MARGIN_TOTAL)
	var style_box := panel_container.get_theme_stylebox("panel")
	if style_box != null:
		chrome += style_box.get_minimum_size()
	return chrome

func _hide_now() -> void:
	_state = State.IDLE
	_active_source = null
	_active_request = null
	set_process(false)

	if tween:
		tween.kill()

	if fade_seconds <= 0.0:
		modulate = Color.TRANSPARENT
		hide()
		return

	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_seconds)
	tween.tween_callback(hide)

func _has_active_source() -> bool:
	if _active_source == null:
		return false
	if !_hovered_sources.has(_active_source):
		return false
	return _is_source_valid(_active_source)

func _get_winning_source() -> Object:
	var winner: Object = null
	var winner_request: TooltipRequest = null
	var winner_order := -1

	for source in _hovered_sources.keys():
		var request := _hovered_sources[source] as TooltipRequest
		if request == null:
			continue

		var enter_order := int(_source_enter_order.get(source, -1))
		if winner == null:
			winner = source
			winner_request = request
			winner_order = enter_order
			continue

		if request.priority > winner_request.priority:
			winner = source
			winner_request = request
			winner_order = enter_order
			continue

		if request.priority == winner_request.priority and enter_order > winner_order:
			winner = source
			winner_request = request
			winner_order = enter_order

	return winner

func _prune_invalid_sources() -> void:
	var stale_sources: Array = []
	for source in _hovered_sources.keys():
		if !_is_source_valid(source):
			stale_sources.append(source)
			continue

		var request := _hovered_sources[source] as TooltipRequest
		if request == null:
			stale_sources.append(source)

	for source in stale_sources:
		_unregister_source(source)

func _unregister_source(source: Object) -> void:
	_hovered_sources.erase(source)
	_source_enter_order.erase(source)
	if source == _active_source:
		_active_source = null
		_active_request = null

func _is_source_valid(source: Object) -> bool:
	if source == null or !is_instance_valid(source):
		return false

	var node := source as Node
	if node != null and !node.is_inside_tree():
		return false

	return true

func _get_anchor_rect(request: TooltipRequest) -> Rect2:
	if request == null:
		return Rect2()

	if request.anchor_control != null and is_instance_valid(request.anchor_control) and request.anchor_control.is_inside_tree():
		return request.anchor_control.get_global_rect()

	if request.anchor_rect.size != Vector2.ZERO:
		return request.anchor_rect

	var active_control := _active_source as Control
	if active_control != null and active_control.is_inside_tree():
		return active_control.get_global_rect()

	return Rect2()

func _cancel_show() -> void:
	if _show_timer != null:
		_show_timer.stop()

func _cancel_hide() -> void:
	if _hide_timer != null:
		_hide_timer.stop()

func _create_timer(timeout_callable: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(timeout_callable)
	add_child(timer)
	return timer
