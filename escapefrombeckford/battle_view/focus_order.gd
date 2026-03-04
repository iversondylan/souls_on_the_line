# focus_order.gd

class_name FocusOrder extends RefCounted

var duration: float = 0.25

var attacker_id: int = 0
var target_ids: Array[int] = []

# Visual intent
var dim_uninvolved: float = 0.55 # multiply alpha or modulate value
var dim_bg: float = 0.55
var scale_involved: float = 1.08
var scale_uninvolved: float = 0.96

# Mild positional drift (pixels)
var drift_involved: float = 12.0
var drift_uninvolved: float = 0.0
