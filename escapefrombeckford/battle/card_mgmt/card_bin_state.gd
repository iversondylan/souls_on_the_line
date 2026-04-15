class_name CardBinState extends RefCounted

var card_collection: CardPile = CardPile.new()
var draw_pile: CardPile = CardPile.new()
var hand_pile: CardPile = CardPile.new()
var discard_pile: CardPile = CardPile.new()
var summon_reserve_pile: CardPile = CardPile.new()
var exhausted_pile: CardPile = CardPile.new()

var summon_reserve_by_uid: Dictionary = {}
var hand_locked_until_next_player_turn: Dictionary = {}

var first_shuffle: bool = true
