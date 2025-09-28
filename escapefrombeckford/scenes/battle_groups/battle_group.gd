class_name BattleGroup extends Node2D



@export var faces_right: bool = true

var battle_scene: BattleScene
var deck: Deck
var turn_table: Dictionary = {}
var turn_taker: TurnTaker
var focus: Fighter = null

func make_turn_table() -> void:
	turn_table.clear()
	var prior_turn_taker: TurnTaker = null
	for child in get_children():
		if child is TurnTaker:
			if prior_turn_taker:
				turn_table[prior_turn_taker] = child as TurnTaker
			prior_turn_taker = child	

func reset_npc_actions() -> void:
	for child in get_children():
		if child is NPCFighter:
			child.current_action = null
			child.update_action()

func start_turn() -> void:
	if turn_taker:
		turn_taker.exit()
	focus = null
	turn_taker = get_child(0)
	turn_taker.enter()

func next_turn_taker(turn_taker_who_finished: TurnTaker) -> void:
	if turn_taker_who_finished != turn_taker:
		return
	turn_taker.exit()
	turn_taker = turn_table[turn_taker]
	turn_taker.enter()

func reboot_turn_taker(next_turn_taker: TurnTaker) -> void:
	print("battlegroup.gd reboot_turn_taker(): overwrite me please")

func get_combatants() -> Array[Fighter]:
	var combatants: Array[Fighter] = []
	for child: TurnTaker in get_children():
		if child is Fighter:# and child.combatant_data.is_alive:
			#if child.combatant_data.is_alive:
			combatants.push_back(child)
	return combatants

func connect_combatants():
	for combatant: Fighter in get_combatants():
		connect_combatant(combatant)

func connect_combatant(fighter: Fighter):
	fighter.turn_taker_turn_complete.connect(_on_turn_taker_turn_complete)

func add_combatant(fighter: Fighter, rank: int):
	var children: Array[Node] = get_children()
	var n_children: int = children.size()
	add_child(fighter)
	Events.n_combatants_changed.emit()
	connect_combatant(fighter)
	fighter.battle_group = self
	#update_combatant_rank_variable()
	move_child(fighter, rank)
	#update_combatant_rank_variable()
	update_combatant_position()
	make_turn_table()
	#debug_function_for_checking_terminal_rank()

#func debug_function_for_checking_terminal_rank() -> void:
	#var index = 0
	#for child: TurnTaker in get_children():
		#print(child.name + " is rank " + str(index))
		#if child is Fighter:
			#print("combatant_data rank is " + str(child.combatant_data.rank))
		#index += 1

func remove_combatant(fighter: Fighter):
	if fighter == turn_taker:
		reboot_turn_taker(turn_table[turn_taker])
	remove_child(fighter)
	Events.n_combatants_changed.emit()
	fighter.queue_free()
	update_combatant_rank_variable()
	update_combatant_position()
	make_turn_table()
	#debug_function_for_checking_terminal_rank()

func clear_combatants() -> void:
	for fighter: Fighter in get_combatants():
		remove_combatant(fighter)
	#debug_function_for_checking_terminal_rank()

func combatant_is_there(fighter: Fighter) -> bool:
	var fighters: Array[Fighter] = get_combatants()
	var combatant_index: int = fighters.find(fighter)
	if combatant_index >= 0:
		return true
	else:
		return false

func update_combatant_rank_variable():
	pass
	#var index: int = 0
	#for child: TurnTaker in get_children():
		#if child is Fighter:
			#if child.combatant_data.is_alive:
			#child.combatant_data.rank = index
			#index += 1

func update_combatant_position():
	var window_dist: int = get_viewport_rect().size.x * 3 / 16
	var left_bound: float = -window_dist
	var right_bound: float = window_dist
	var fighters: Array[Fighter] = get_combatants()
	var n_fighters: int = fighters.size()
	var increment: float = (right_bound - left_bound) / (n_fighters + 1)
	var n: int = 1
	for fighter in fighters:
		if faces_right:
			fighter.set_anchor_position(Vector2(right_bound-increment*n, 0), false)
		else:
			fighter.set_anchor_position(Vector2(left_bound+increment*n, 0), false)
		n += 1

func combatant_died(fighter: Fighter):
	#var combatant_doing_turn: bool = fighter.doing_turn
	if fighter is SummonedAlly:
		deck.discard_summon_reserve_card(fighter.card_data)
	Events.dead_combatant_data.emit(fighter.combatant_data)
	remove_combatant(fighter)
	if get_child_count() == 1:
		Events.battle_group_empty.emit(self)
	#if combatant_doing_turn:
		#Events.npc_action_completed.emit(self)


func _on_turn_taker_turn_complete(turn_taker_who_finished: TurnTaker) -> void:
	#if BattleController.current_state != BattleController.BattleState.FRIENDLY_TURN:
		#return
	next_turn_taker(turn_taker_who_finished)
