class_name Tooltip extends PanelContainer

@export var fade_seconds: float = 0.2
@onready var tooltip_icon: TextureRect = %TooltipIcon
@onready var tooltip_description: RichTextLabel = %TooltipDescription
var tween: Tween
var is_visible: bool = false

func _ready() -> void:
	Events.icon_tooltip_show_requested.connect(show_tooltip)
	Events.icon_tooltip_hide_requested.connect(hide_tooltip)
	modulate = Color.TRANSPARENT
	hide()

func show_tooltip(intent_display: IntentDisplay) -> void:
	is_visible = true
	if tween:
		tween.kill()
	position = intent_display.global_position
	tooltip_icon.texture = intent_display.intent_data.icon
	tooltip_description.text = intent_display.intent_data.tooltip_text
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(show)
	tween.tween_property(self, "modulate", Color.WHITE, fade_seconds)

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
