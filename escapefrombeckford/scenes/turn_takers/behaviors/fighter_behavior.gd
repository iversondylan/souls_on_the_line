class_name FighterBehavior extends Node

func _ready() -> void:
	pass

func _on_combatant_data_set(_data: CombatantData) -> void:
	pass

func load_ai():
	pass

func _on_enter() -> void:
	pass

func update_action() -> void:
	pass

func update_action_intent() -> void:
	pass

func _set_current_action(_current_action: NPCAction) -> void:
	pass

func _on_exit() -> void:
	pass

func _on_do_turn() -> void:
	pass

func _on_hand_drawn() -> void:
	pass

func _on_hand_discarded() -> void:
	pass

func _on_end_turn_button_pressed() -> void:
	pass

func _on_modifier_changed() -> void:
	pass

func _on_die() -> void:
	pass

func bind_card(_new_card_data: CardData) -> void:
	pass

func _on_traverse_player() -> void:
	pass

func get_sibling(_name: String) -> Node:
	return null

func _on_discard_summon_reserve_card(_deck: Deck) -> void:
	pass
