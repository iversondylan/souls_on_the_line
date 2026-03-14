# draw_context.gd

class_name DrawContext extends RefCounted


var source_id: int
var battle: Battle
var hand: Hand
var deck: Deck

var amount: int = 0

var actually_drawn: int = 0
var reason: String = ""
