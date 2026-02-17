# player_behavior.gd

class_name PlayerBehavior extends FighterBehavior # FighterBehavior extends Node

func _on_combatant_data_set(new_owner: Fighter) -> void:
	#print("player_behavior.gd _on_combatant_data_set()")
	owner = new_owner
	#var player: Player = get_parent()
	if !owner.is_node_ready():
		await owner.ready
	if !Events.hand_discarded.is_connected(_on_hand_discarded):
		Events.hand_discarded.connect(_on_hand_discarded)

func _on_do_turn() -> void:
	# Player turn flow is managed by Battle.gd now.
	#var fighter: Fighter = get_parent()
	owner.combatant_data.reset_armor()
	owner.combatant_data.reset_mana()
	Events.request_draw_hand.emit()
	pass

func _on_hand_discarded() -> void:
	#var fighter: Fighter = get_parent()
	owner.resolve_action()

func _on_modifier_changed() -> void:
	Events.player_modifier_changed.emit()

func _on_battle_reset() -> void:
	#var fighter: Fighter = get_parent()
	owner.combatant_data.reset_armor()
	owner.combatant_data.reset_mana()
