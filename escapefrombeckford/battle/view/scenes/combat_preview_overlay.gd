class_name CombatPreviewOverlay
extends Node2D

@onready var _icon_parent: Node2D = $IconParent
#@onready var _icon: Sprite2D = $IconParent/Icon
@onready var _text_parent: Node2D = $TextParent
@onready var _label: Label = $TextParent/Label

const DAMAGE_COLOR := Color(0.88, 0.18, 0.18, 1.0)
const HEAL_COLOR := Color(0.22, 0.74, 0.28, 1.0)
const NEUTRAL_COLOR := Color(0.9, 0.9, 0.9, 1.0)


func _ready() -> void:
	clear_preview()


func clear_preview() -> void:
	visible = false
	_icon_parent.visible = false
	_text_parent.visible = false
	_label.text = ""


func show_death_preview() -> void:
	visible = true
	_icon_parent.visible = true
	_text_parent.visible = false


func show_health_preview(current_health: int, _max_hp: int, previous_health: int) -> void:
	visible = true
	_icon_parent.visible = false
	_text_parent.visible = true
	var delta_health := current_health - previous_health
	if delta_health < 0:
		_label.text = "%d" % delta_health
		_label.modulate = DAMAGE_COLOR
	elif delta_health > 0:
		_label.text = "+%d" % delta_health
		_label.modulate = HEAL_COLOR
	else:
		visible = false
