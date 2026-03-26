class_name CardMoveContext extends RefCounted

enum BinKind {
	DRAW_PILE,
	HAND,
	DISCARD_PILE,
	SUMMON_RESERVE,
	EXHAUSTED,
}

var source_id: int = 0
var from_bin: int = BinKind.DRAW_PILE
var to_bin: int = BinKind.HAND
var card_uids: Array[String] = []
var moved_cards: Array[CardData] = []
var actually_moved: int = 0
var reason: String = ""
var phase: String = ""
var tags: Array[String] = []
