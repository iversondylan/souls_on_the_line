class_name RemovalContext extends RefCounted


var target_id: int = 0
var removal_type: int = Removal.Type.DEATH
var group_index: int = -1
var insert_index: int = -1
var reason: String = ""
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""
var before_order_ids: PackedInt32Array = PackedInt32Array()
var after_order_ids: PackedInt32Array = PackedInt32Array()
var removed: bool = false
var prevented: bool = false
var overload_mod: int = 0
var reserve_release_destination: int = CardMoveContext.BinKind.DISCARD_PILE
var reserve_release_overload_override: int = -1
var released_reserve_card_uid: String = ""

var killer_id: int = 0
var event_extra := {}
var vfx_payloads: Array[Dictionary] = []
