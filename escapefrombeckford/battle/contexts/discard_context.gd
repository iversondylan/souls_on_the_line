# discard_context.gd
class_name DiscardContext extends RefCounted

var request_id: int = 0
var source_id: int = 0
var amount: int = 0
var card_uid: String = ""
var requested_card_uids: Array[String] = []
var discarded_card_uids: Array[String] = []
var actually_discarded : int = 0
var discard_all_from_hand: bool = false
var reason: String = ""
var phase: String = ""
var tags: Array[String] = []
# callback: func(chosen_uids: Array[String]) -> void
var on_done: Callable = Callable()
