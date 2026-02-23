# card_play_request.gd

class_name CardPlayRequest extends RefCounted

var source_id: int = 0          # who played it (combat_id)
var card_id: int = 0            # or StringName if you prefer
var targets: PackedInt32Array = PackedInt32Array()  # chosen target combat_ids
var area_index: int = -1        # for battlefield targeting / insert positions
var params: Dictionary = {}     # flexible: "swap_partner_id", "replace_id", etc.
