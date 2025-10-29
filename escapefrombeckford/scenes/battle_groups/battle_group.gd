class_name BattleGroup extends Node2D



@export var faces_right: bool = true

var battle_scene: BattleScene
var deck: Deck
var focus: Fighter = null

var acting_fighters: Array[Fighter] = []

func reset_npc_actions() -> void:
	for child in get_children():
		if child is NPCFighter:
			child.current_action = null
			child.update_action()

func start_turn() -> void:
	if get_child_count() == 0:
		print("battle_group.gd start_turn() ERROR: stuck with no fighters")
		return
	acting_fighters.clear()
	for fighter: Fighter in get_children():
		acting_fighters.append(fighter)
	focus = null
	_next_turn_taker()

func _next_turn_taker() -> void:
	if acting_fighters.is_empty():
		if self is BattleGroupEnemy:
			BattleController.transition(BattleController.BattleState.FRIENDLY_TURN)
		elif self is BattleGroupFriendly:
			BattleController.transition(BattleController.BattleState.ENEMY_TURN)
		return
	acting_fighters[0].enter()

func get_combatants() -> Array[Fighter]:
	var combatants: Array[Fighter] = []
	for child: Fighter in get_children():
		combatants.push_back(child)
	return combatants

func connect_combatant(fighter: Fighter):
	fighter.combatant.status_grid.statuses_applied.connect(_on_combatant_statuses_applied.bind(fighter))
	fighter.turn_taker_turn_complete.connect(_on_turn_taker_turn_complete)

func add_combatant(fighter: Fighter, rank: int):
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
	for combatant in get_children():
		if !acting_fighters.has(combatant):
			acted += 1
	if rank - acted > 0:
		acting_fighters.insert(rank - acted, fighter)

func remove_combatant(fighter: Fighter):
	remove_child(fighter)
	var dead_fighter_acting: bool = false
	if !acting_fighters.is_empty():
		dead_fighter_acting = fighter == acting_fighters[0]
	acting_fighters.erase(fighter)
	fighter.queue_free()
	Events.n_combatants_changed.emit()
	update_combatant_position()
	if get_child_count() == 0:
		Events.battle_group_empty.emit(self)
	
	if !dead_fighter_acting:
		return
	
	
	if self is BattleGroupEnemy:
		if BattleController.current_state == BattleController.BattleState.ENEMY_TURN:
			_next_turn_taker()
	elif self is BattleGroupFriendly:
		if BattleController.current_state == BattleController.BattleState.FRIENDLY_TURN:
			_next_turn_taker()

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
	if fighter is SummonedAlly:
		fighter.discard_summon_reserve_card(deck)
	Events.dead_combatant_data.emit(fighter.combatant_data)
	remove_combatant(fighter)

func _on_turn_taker_turn_complete(turn_taker_who_finished: Fighter) -> void:
	turn_taker_who_finished.exit()
	

func _on_combatant_statuses_applied(proc_type: Status.ProcType, fighter: Fighter) -> void:
	match proc_type:
		Status.ProcType.START_OF_TURN:
			fighter.do_turn()
		Status.ProcType.END_OF_TURN:
			acting_fighters.erase(fighter)
			_next_turn_taker()
