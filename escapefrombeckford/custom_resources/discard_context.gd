# discard_context.gd

class_name DiscardContext extends RefCounted


var source: Fighter
var battle: Battle
var hand: Hand
var deck: Deck

var amount: int = 0

var actually_discarded: int = 0
var reason: String = ""
