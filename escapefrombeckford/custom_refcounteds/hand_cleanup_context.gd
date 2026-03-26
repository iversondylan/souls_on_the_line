class_name HandCleanupContext extends RefCounted

var source_id: int = 0
var cleanup_kind: String = ""
var phase: String = ""
var should_discard_hand: bool = true
var should_exhaust_hand: bool = false
var cards_to_keep: Array[String] = []
var discarded_card_uids: Array[String] = []
var exhausted_card_uids: Array[String] = []
var kept_card_uids: Array[String] = []
var actually_moved_card_uids: Array[String] = []
var reason: String = ""
var tags: Array[String] = []
