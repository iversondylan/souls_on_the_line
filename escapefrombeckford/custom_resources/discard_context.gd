# discard_context.gd
class_name DiscardContext extends RefCounted

var request_id: int = 0
var source_id: int = 0
var amount: int = 0
var card_uid: String = ""

# UI can fill these in (BattleInteractionHandler does that today)
var battle : Battle = null
var hand : Hand = null
var deck : Deck = null

var actually_discarded : int
# callback: func(chosen_uids: Array[String]) -> void
var on_done: Callable = Callable()

## discard_context.gd
#
#class_name DiscardContext extends RefCounted
#
#
#var source: Fighter
#var battle: Battle
#var hand: Hand
#var deck: Deck
#
#var amount: int = 0
#
#var actually_discarded: int = 0
#var reason: String = ""
