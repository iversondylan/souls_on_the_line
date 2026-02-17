# fighter_behavior.gd

class_name FighterBehavior extends Resource

var owner: Fighter

func _on_combatant_data_set(new_owner: Fighter) -> void:
	owner = new_owner

func _on_enter() -> void:
	pass

func _on_opposing_group_turn_start() -> void: pass

func update_action_intent() -> void:
	pass

func _on_exit() -> void:
	pass

func _on_do_turn() -> void:
	pass

func _on_group_turn_end() -> void:
	pass

func _on_hand_discarded() -> void:
	pass

func _on_modifier_changed() -> void:
	pass

func _on_die() -> void:
	pass

func _on_fade() -> void:
	pass

func bind_card(_new_card_data: CardData) -> void:
	pass

func _on_discard_summon_reserve_card(_deck: Deck) -> void:
	pass

func _on_battle_reset() -> void:
	pass
