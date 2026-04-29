class_name StatusDepictionFxCommand
extends RefCounted

enum Op { ENSURE_PERSISTENT, CLEAR_PERSISTENT }

var op: Op = Op.ENSURE_PERSISTENT
var key: String = ""
var fx_id: StringName = &""
var target_id: int = 0
var fade_in: float = 0.06
var fade_out: float = 0.06
var scale: float = 1.05
var center_y_ratio: float = 0.5
