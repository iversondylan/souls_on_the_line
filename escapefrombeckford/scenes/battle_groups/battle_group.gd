class_name BattleGroup extends Node2D



@export var faces_right: bool = true

var battle_scene: BattleScene
var deck: Deck
var turn_table: Dictionary = {}
var turn_taker: TurnTaker
var focus: Fighter = null

var acting_fighters: Array[Fighter] = []

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
	#print("battle_group.gd start_turn()")
	if get_child_count() == 0:
		print("battle_group.gd start_turn() ERROR: stuck with no fighters")
		return
	acting_fighters.clear()
	#Change this to be only fighters, not turn takers
	for fighter: TurnTaker in get_children():
		acting_fighters.append(fighter)
	#if turn_taker:
		#turn_taker.exit()
	focus = null
	#turn_taker = get_child(0)
	#turn_taker.enter()
	_next_turn_taker()

func _next_turn_taker() -> void:
	#print("_nedt_turn_taker() acting_fighters: ", acting_fighters)
	if acting_fighters.is_empty():
		#print("acting_fighters is empty")
		if self is BattleGroupEnemy:
			#print("transitioning to friendly turn")
			BattleController.transition(BattleController.BattleState.FRIENDLY_TURN)
		elif self is BattleGroupFriendly:
			#print("transitioning to enemy turn")
			BattleController.transition(BattleController.BattleState.ENEMY_TURN)
		return
	#print("battle_group.gd next_turn_taker(turn_taker_who_finished: %s)" % turn_taker_who_finished)
	#if turn_taker_who_finished != turn_taker:
		#print("battle_group.gd next_turn_taker() ERROR: turn taker who finished is not current turn taker")
		#return
	acting_fighters[0].enter()
	#turn_taker = turn_table[turn_taker]
	#turn_taker_who_finished.exit()

#func reboot_turn_taker(next_turn_taker: TurnTaker) -> void:
	#print("battlegroup.gd reboot_turn_taker(): overwrite me please")

func get_combatants() -> Array[Fighter]:
	var combatants: Array[Fighter] = []
	for child: Fighter in get_children():
		#if child is Fighter:# and child.combatant_data.is_alive:
			#if child.combatant_data.is_alive:
		combatants.push_back(child)
	return combatants

#func connect_combatants():
	#for combatant: Fighter in get_combatants():
		#connect_combatant(combatant)

func connect_combatant(fighter: Fighter):
	#print("battle_group.gd connect_combatant(%s)" % fighter.name)
	fighter.combatant.status_grid.statuses_applied.connect(_on_combatant_statuses_applied.bind(fighter))
	fighter.turn_taker_turn_complete.connect(_on_turn_taker_turn_complete)

func add_combatant(fighter: Fighter, rank: int):
	#print("battle_group.gd add_combatant() adding fighter at rank %s" % rank)
	var children: Array[Node] = get_children()
	var n_children: int = children.size()
	add_child(fighter)
	connect_combatant(fighter)
	fighter.battle_group = self
	move_child(fighter, rank)
	Events.n_combatants_changed.emit()
	update_combatant_position()
	
	if acting_fighters.is_empty():
		return
	
	var acted: int = -1
	#for element in get_children():
		#print("get_children()", element, " (", typeof(element), ")")
	#for element in acting_fighters:
		#print("acting_fighters", element, " (", typeof(element), ")")
	for combatant in get_children():
		if !acting_fighters.has(combatant):
			acted += 1
	#print("acting_fighters: %s, acted: %s" % [acting_fighters, acted])
	if rank - acted > 0:
		acting_fighters.insert(rank - acted, fighter)
	
		
	#make_turn_table()

func remove_combatant(fighter: Fighter):
	#print("battle_group.gd remove_combatant()")
	#print("battle_group.gd remove_combatant()")
	#if fighter == turn_taker:
		#reboot_turn_taker(turn_table[turn_taker])
	remove_child(fighter)
	var dead_fighter_acting: bool = false
	if !acting_fighters.is_empty():
		dead_fighter_acting = fighter == acting_fighters[0]
	acting_fighters.erase(fighter)
	fighter.queue_free()
	Events.n_combatants_changed.emit()
	#update_combatant_rank_variable()
	update_combatant_position()
	if get_child_count() == 1:
		Events.battle_group_empty.emit(self)
	
	if !dead_fighter_acting:
		return
	
	match self:
		BattleGroupEnemy:
			if BattleController.current_state == BattleController.BattleState.ENEMY_TURN:
				_next_turn_taker()
		BattleGroupFriendly:
			if BattleController.current_state == BattleController.BattleState.FRIENDLY_TURN:
				_next_turn_taker()
	#make_turn_table()
	

func clear_combatants() -> void:
	for fighter: Fighter in get_combatants():
		remove_combatant(fighter)

func combatant_is_there(fighter: Fighter) -> bool:
	var fighters: Array[Fighter] = get_combatants()
	var combatant_index: int = fighters.find(fighter)
	if combatant_index >= 0:
		return true
	else:
		return false

#func update_combatant_rank_variable():
	#pass
	#var index: int = 0
	#for child: TurnTaker in get_children():
		#if child is Fighter:
			#if child.combatant_data.is_alive:
			#child.combatant_data.rank = index
			#index += 1

func update_combatant_position():
	#print("battle_group.gd update_combatant_position()")
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
	if fighter is SummonedAlly:
		deck.discard_summon_reserve_card(fighter.card_data)
	Events.dead_combatant_data.emit(fighter.combatant_data)
	remove_combatant(fighter)

func _on_turn_taker_turn_complete(turn_taker_who_finished: TurnTaker) -> void:
	#print("battle_group.gd _on_turn_taker_turn_complete(%s)" % turn_taker_who_finished.name)
	turn_taker_who_finished.exit()
	

func _on_combatant_statuses_applied(proc_type: Status.ProcType, fighter: Fighter) -> void:
	#print("battle_group.gd _on_combatant_statuses_applied()")
	#if fighter.turn_taker_turn_complete.is_connected(_on_turn_taker_turn_complete):
		#print("is connected")
	#else:
		#print("is not connected")
	match proc_type:
		Status.ProcType.START_OF_TURN:
			fighter.do_turn()
		Status.ProcType.END_OF_TURN:
			acting_fighters.erase(fighter)
			_next_turn_taker()
			#turn_taker.enter()
