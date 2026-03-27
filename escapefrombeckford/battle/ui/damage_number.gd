# damage_number.gd

class_name DamageNumber extends Node2D

@onready var damage_number_label: Label = $DamageText

func animate_and_vanish(damage_value: int, height: int) -> void:
	damage_number_label.text = str(damage_value)
	position = Vector2(0, -height)
	var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", Vector2.UP*15, 1).as_relative()
	tween.tween_callback(queue_free)
