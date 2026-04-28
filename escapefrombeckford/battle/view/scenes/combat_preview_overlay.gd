class_name CombatPreviewOverlay
extends Node2D

@onready var _icon_parent: Node2D = $IconParent
#@onready var _icon: Sprite2D = $IconParent/Icon
@onready var _text_parent: Node2D = $TextParent
@onready var _label: Label = $TextParent/Label
@onready var _targeted_icon: Sprite2D = $TextParent.get_node_or_null("TargetedIcon") as Sprite2D
@onready var _danger_zone_icon: Sprite2D = $TextParent.get_node_or_null("DangerZoneIcon") as Sprite2D

const DAMAGE_COLOR := Color(0.88, 0.18, 0.18, 1.0)
const HEAL_COLOR := Color(0.22, 0.74, 0.28, 1.0)
const NEUTRAL_COLOR := Color(0.9, 0.9, 0.9, 1.0)

var _has_forecast_text := false
var _has_forecast_icon := false
var _targeted_marker_keys: Dictionary = {}
var _danger_zone_marker_keys: Dictionary = {}


func _ready() -> void:
	clear_preview()


func clear_preview() -> void:
	_has_forecast_text = false
	_has_forecast_icon = false
	_label.text = ""
	_refresh_visibility()


func show_death_preview() -> void:
	_has_forecast_icon = true
	_has_forecast_text = false
	_label.text = ""
	_refresh_visibility()


func show_health_preview(current_health: int, _max_hp: int, previous_health: int) -> void:
	_has_forecast_icon = false
	_has_forecast_text = true
	var delta_health := current_health - previous_health
	if delta_health < 0:
		_label.text = "%d" % delta_health
		_label.modulate = DAMAGE_COLOR
	elif delta_health > 0:
		_label.text = "+%d" % delta_health
		_label.modulate = HEAL_COLOR
	else:
		_has_forecast_text = false
		_label.text = ""
	_refresh_visibility()


func set_status_depiction_marker(marker_key: String, marker_kind: StringName, show_it: bool) -> void:
	if marker_key.is_empty():
		return
	match marker_kind:
		StatusDepiction.MARKER_TARGETED:
			_set_marker_key(_targeted_marker_keys, marker_key, show_it)
		StatusDepiction.MARKER_DANGER_ZONE:
			_set_marker_key(_danger_zone_marker_keys, marker_key, show_it)
	_refresh_visibility()


func clear_status_depiction_marker_key(marker_key: String) -> void:
	if marker_key.is_empty():
		return
	_targeted_marker_keys.erase(marker_key)
	_danger_zone_marker_keys.erase(marker_key)
	_refresh_visibility()


func clear_status_depiction_marker_prefix(marker_prefix: String) -> void:
	if marker_prefix.is_empty():
		return
	_clear_marker_prefix(_targeted_marker_keys, marker_prefix)
	_clear_marker_prefix(_danger_zone_marker_keys, marker_prefix)
	_refresh_visibility()


func clear_all_status_depictions() -> void:
	_targeted_marker_keys.clear()
	_danger_zone_marker_keys.clear()
	_refresh_visibility()


func _set_marker_key(marker_keys: Dictionary, marker_key: String, show_it: bool) -> void:
	if show_it:
		marker_keys[marker_key] = true
	else:
		marker_keys.erase(marker_key)


func _clear_marker_prefix(marker_keys: Dictionary, marker_prefix: String) -> void:
	var prefix_with_separator := "%s:" % marker_prefix
	for marker_key in marker_keys.keys():
		var key := String(marker_key)
		if key == marker_prefix or key.begins_with(prefix_with_separator):
			marker_keys.erase(marker_key)


func _has_visible_marker(marker_keys: Dictionary) -> bool:
	return !marker_keys.is_empty()


func _refresh_visibility() -> void:
	var show_targeted := _has_visible_marker(_targeted_marker_keys)
	var show_danger_zone := _has_visible_marker(_danger_zone_marker_keys)
	var show_text_parent := _has_forecast_text or show_targeted or show_danger_zone

	visible = _has_forecast_icon or show_text_parent
	_icon_parent.visible = _has_forecast_icon
	_text_parent.visible = show_text_parent
	_label.visible = _has_forecast_text
	if _targeted_icon != null:
		_targeted_icon.visible = show_targeted
	if _danger_zone_icon != null:
		_danger_zone_icon.visible = show_danger_zone
