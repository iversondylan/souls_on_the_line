class_name Tooltip extends Control

@export var fade_seconds: float = 0.2

const MIN_PANEL_WIDTH := 220.0
const MAX_PANEL_WIDTH := 520.0
const VIEWPORT_WIDTH_RATIO := 0.4
const TEXT_PADDING_WIDTH := 120.0
const TEXT_WIDTH_PER_CHARACTER := 6.0
const CONTENT_MARGIN_TOTAL := 10.0

@onready var tooltip_icon: TextureRect = %TooltipIcon
@onready var tooltip_description: RichTextLabel = %TooltipDescription
@onready var panel_container: PanelContainer = $PanelContainer

var tween: Tween
var is_visible: bool = false

func _ready() -> void:
	Events.tooltip_show_requested.connect(show_tooltip)
	Events.tooltip_hide_requested.connect(hide_tooltip)
	tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_description.fit_content = false
	modulate = Color.TRANSPARENT
	hide()

func show_tooltip(request: TooltipRequest) -> void:
	if request == null:
		return

	is_visible = true
	if tween:
		tween.kill()

	tooltip_icon.visible = !request.icon_uid.is_empty()
	tooltip_icon.texture = load(request.icon_uid) if tooltip_icon.visible else null
	_resize_panel(request)
	_position_panel(request)

	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(show)
	tween.tween_property(self, "modulate", Color.WHITE, fade_seconds)

func _position_panel(request: TooltipRequest) -> void:
	var viewport_rect := get_viewport_rect()
	var panel_size := panel_container.size
	var anchor_rect := request.anchor_rect
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

func _resize_panel(request: TooltipRequest) -> void:
	var viewport_rect := get_viewport_rect()
	var max_panel_width := viewport_rect.size.x * VIEWPORT_WIDTH_RATIO
	if max_panel_width > MAX_PANEL_WIDTH:
		max_panel_width = MAX_PANEL_WIDTH
	var target_panel_width := clampf(_estimate_panel_width(request.text_bbcode), MIN_PANEL_WIDTH, max_panel_width)
	var panel_chrome := _get_panel_chrome_size()
	var target_text_width := maxf(target_panel_width - panel_chrome.x, 0.0)
	var max_chars_per_line := maxi(12, int(floor(target_text_width / TEXT_WIDTH_PER_CHARACTER)))
	var wrapped_text := _wrap_bbcode_text(request.text_bbcode, max_chars_per_line)

	tooltip_icon.custom_minimum_size = Vector2(64, 64) if tooltip_icon.visible else Vector2.ZERO
	tooltip_description.clear()
	tooltip_description.append_text(wrapped_text)
	tooltip_description.custom_minimum_size = Vector2(target_text_width, 0.0)
	tooltip_description.size = Vector2(target_text_width, 0.0)
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

func _wrap_bbcode_text(text_bbcode: String, max_chars_per_line: int) -> String:
	var wrapped_lines: Array[String] = []
	for raw_line in text_bbcode.split("\n"):
		var current_line := ""
		var current_visible_length := 0
		for word in raw_line.split(" ", false):
			var visible_word_length := _strip_bbcode(word).length()
			var separator_length := 0 if current_line.is_empty() else 1
			if !current_line.is_empty() and current_visible_length + separator_length + visible_word_length > max_chars_per_line:
				wrapped_lines.append(current_line)
				current_line = word
				current_visible_length = visible_word_length
				continue

			if !current_line.is_empty():
				current_line += " "
				current_visible_length += 1
			current_line += word
			current_visible_length += visible_word_length

		wrapped_lines.append(current_line)

	return "\n".join(wrapped_lines)

func _get_panel_chrome_size() -> Vector2:
	var chrome := Vector2(CONTENT_MARGIN_TOTAL, CONTENT_MARGIN_TOTAL)
	var style_box := panel_container.get_theme_stylebox("panel")
	if style_box != null:
		chrome += style_box.get_minimum_size()
	return chrome

func hide_tooltip() -> void:
	is_visible = false
	if tween:
		tween.kill()
	get_tree().create_timer(fade_seconds, false).timeout.connect(hide_animation)

func hide_animation() -> void:
	if !is_visible:
		tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_seconds)
		tween.tween_callback(hide)
