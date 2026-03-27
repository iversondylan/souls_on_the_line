class_name BlockedMessage extends Node2D

@onready var blocked_message_label: Label = $BlockedText

func animate_and_vanish(height: int) -> void:
	position = Vector2(0, -height)
	var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", Vector2.UP*15, 1).as_relative()
	tween.tween_callback(queue_free)
