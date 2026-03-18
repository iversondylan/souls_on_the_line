# mana_view_order.gd

class_name ManaViewOrder extends RefCounted

var duration: float = 0.0

var source_id: int = 0
var before_mana: int = 0
var after_mana: int = 0
var before_max_mana: int = 0
var after_max_mana: int = 0

var reason: String = ""
