class_name Tooltip extends Control

@export var fade_seconds: float = 0.2

@onready var tooltip_icon: TextureRect = %TooltipIcon
@onready var tooltip_description: RichTextLabel = %TooltipDescription
@onready var panel_container: PanelContainer = $PanelContainer

var tween: Tween
var is_visible: bool = false

func _ready() -> void:
	Events.tooltip_show_requested.connect(show_tooltip)
	Events.tooltip_hide_requested.connect(hide_tooltip)
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
	tooltip_description.clear()
	tooltip_description.append_text(request.text_bbcode)
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
