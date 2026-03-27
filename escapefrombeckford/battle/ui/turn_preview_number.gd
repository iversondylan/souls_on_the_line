# turn_preview_number.gd
class_name TurnPreviewNumber extends Node2D

@onready var base: RichTextLabel = $OrdinalHBox/Base
@onready var suffix: RichTextLabel = $OrdinalHBox/Suffix

const FADE_TIME := 0.22

var _fade_tween: Tween

func _ready() -> void:
	set_ordinal(1)

func set_ordinal(n: int) -> void:
	# Base number
	base.text = str(n)

	# Suffix with 11/12/13 exception
	var mod100 : int = abs(n) % 100
	var mod10 : int = abs(n) % 10

	var s := "th"
	if mod100 < 11 or mod100 > 13:
		match mod10:
			1: s = "st"
			2: s = "nd"
			3: s = "rd"
			_: s = "th"

	suffix.text = s

func fade_out() -> void:
	if _fade_tween and is_instance_valid(_fade_tween):
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_LINEAR)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)

	# Fade both labels (works even if their alphas differ)
	_fade_tween.tween_property(base, "modulate:a", 0.0, FADE_TIME)
	_fade_tween.parallel().tween_property(suffix, "modulate:a", 0.0, FADE_TIME)

	_fade_tween.tween_callback(func():
		queue_free()
	)

func set_color(new_color: Color) -> void:
	# Preserve each label's current alpha (so this won't undo fade progress)
	if base and is_instance_valid(base):
		var c := new_color
		c.a = base.modulate.a
		base.modulate = c

	if suffix and is_instance_valid(suffix):
		var c2 := new_color
		c2.a = suffix.modulate.a
		suffix.modulate = c2
