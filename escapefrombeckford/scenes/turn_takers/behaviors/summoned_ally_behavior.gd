class_name SummonedAllyBehavior extends FighterBehavior

var card_data: CardData

func _ready() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_node_ready():
		await fighter.ready
	#fighter.reset()
	#get_sibling("NPCAIBehavior").update_action()

func _on_die() -> void:
	var summoned_ally: SummonedAlly = get_parent()
	Events.summon_reserve_card_released.emit(summoned_ally)

func bind_card(_new_card_data: CardData) -> void:
	card_data = _new_card_data

func _on_traverse_player() -> void:
	var fighter: Fighter = get_parent()
	fighter.battle_group.ally_traverse_player(fighter)

func get_sibling(_name: String) -> Node:
	return get_parent().get_node_or_null(_name)

func _on_discard_summon_reserve_card(_deck: Deck) -> void:
	_deck.discard_summon_reserve_card(card_data)
