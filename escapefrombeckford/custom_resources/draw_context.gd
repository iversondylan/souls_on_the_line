# draw_context.gd

class_name DrawContext extends RefCounted

var source_id: int = 0
var amount: int = 0
var actually_drawn: int = 0
var reason: String = ""
var phase: String = ""
var tags: Array[String] = []
var use_first_hand_summon_guarantee: bool = false
var drawn_cards: Array[CardData] = []
var drawn_card_uids: Array[String] = []
