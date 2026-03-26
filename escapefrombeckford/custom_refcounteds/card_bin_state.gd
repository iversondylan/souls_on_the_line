class_name CardBinState extends RefCounted

var card_collection: CardPile = CardPile.new()
var draw_pile: CardPile = CardPile.new()
var hand_pile: CardPile = CardPile.new()
var discard_pile: CardPile = CardPile.new()
var summon_reserve_pile: CardPile = CardPile.new()
var exhausted_pile: CardPile = CardPile.new()

var summon_reserve_by_uid: Dictionary = {}

var first_shuffle: bool = true
var first_hand_drawn: bool = false
var first_hand_summon_guarantee: bool = true
