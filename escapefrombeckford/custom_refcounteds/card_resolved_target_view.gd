# card_resolved_target_view.gd

class_name CardResolvedTargetView extends RefCounted

var views: Array[CombatantView] = []
var fighter_ids: PackedInt32Array = PackedInt32Array()

# battlefield placement (summon, etc.)
var areas: Array[Node] = []
var insert_index: int = -1
