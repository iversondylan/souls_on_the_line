# battle_group.gd
class_name BattleGroup extends Node2D

@export var faces_right: bool = true

var battle_scene: BattleScene
var deck: Deck
var run: Run

var acting_fighters: Array[Fighter] = []
var _restored_turn_this_group_turn: Dictionary = {} # int instance_id -> true

func reset_npc_actions() -> void:
	for child in get_children():
		if has_ai_behavior(child):
			child.current_action = null
			#child.update_action()

func start_turn() -> void:
	if get_child_count() == 0:
		print("battle_group.gd start_turn() ERROR: stuck with no fighters")
		return
	_restored_turn_this_group_turn.clear()
	acting_fighters.clear()
	
	for fighter: Fighter in get_children():
		acting_fighters.append(fighter)
	_next_turn_taker()

func _next_turn_taker() -> void:
	if acting_fighters.is_empty():
		end_turn()
		return
	acting_fighters[0].enter()

func end_turn() -> void:
	if self is BattleGroupEnemy:
		Events.request_friendly_turn.emit()
	elif self is BattleGroupFriendly:
		Events.request_enemy_turn.emit()

func my_turn_start() -> void:
	for fighter: Fighter in get_combatants():
		fighter.my_group_turn_start()

func opposing_turn_start() -> void:
	for fighter: Fighter in get_combatants():
		fighter.opposing_group_turn_start()

func my_turn_end() -> void:
	for fighter: Fighter in get_combatants():
		fighter.my_group_turn_end()

func opposing_turn_end() -> void:
	for fighter: Fighter in get_combatants():
		fighter.opposing_group_turn_end()

func get_combatants() -> Array[Fighter]:
	var combatants: Array[Fighter] = []
	for child: Fighter in get_children():
		if child.is_alive():
			combatants.push_back(child)
	return combatants

func connect_combatant(fighter: Fighter):
	fighter.battle_group = self
	fighter.run = run
	fighter.statuses_applied.connect(_on_combatant_statuses_applied.bind(fighter))
	fighter.action_resolved.connect(_on_turn_taker_action_resolved)
	fighter.combatant.status_grid.modifier_tokens_changed.connect(battle_scene._on_modifier_tokens_changed)

func add_combatant(fighter: Fighter, rank: int):
	add_child(fighter)
	connect_combatant(fighter)
	move_child(fighter, rank)
	Events.n_combatants_changed.emit()
	update_combatant_position()
	_recompute_intents_for_group()
	
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
	_recompute_intents_for_group()
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

func _get_layout_params() -> Dictionary:
	var window_dist := get_window_dist()
	var left_bound := -window_dist
	var right_bound := window_dist
	
	var fighters := get_combatants()
	var n_fighters := fighters.size()
	
	var increment := 0.0
	if n_fighters > 0:
		increment = (right_bound - left_bound) / (n_fighters + 1)
	
	return {
		"left": left_bound,
		"right": right_bound,
		"increment": increment,
		"n_fighters": n_fighters
	}

func _get_x_for_slot(slot: float) -> float:
	var p := _get_layout_params()
	
	if p.n_fighters == 0:
		return 0.0
	
	if faces_right:
		return p.right - p.increment * slot
	else:
		return p.left + p.increment * slot


func update_combatant_position():
	var fighters := get_combatants()
	var slot := 1.0
	
	for fighter in fighters:
		var x := _get_x_for_slot(slot)
		fighter.set_anchor_position(Vector2(x, 0), true)
		slot += 1.0

func execute_move(effect: MoveEffect) -> void:
	if !effect or !effect.actor:
		return

	var before_order: Array[Fighter] = get_combatants()
	var before_acting: Array[Fighter] = acting_fighters.duplicate()

	match effect.move_type:
		MoveEffect.MoveType.TRAVERSE_PLAYER:
			if self is BattleGroupFriendly:
				(self as BattleGroupFriendly)._traverse_player(effect.actor)
			else:
				push_warning("BattleGroup.execute_move() tried to traverse player on non-friendly group.")

		MoveEffect.MoveType.MOVE_TO_FRONT:
			move_child(effect.actor, 0)

		MoveEffect.MoveType.MOVE_TO_BACK:
			move_child(effect.actor, get_child_count() - 1)

		MoveEffect.MoveType.SWAP_WITH_TARGET:
			if effect.target:
				_swap(effect.actor, effect.target)

		MoveEffect.MoveType.INSERT_AT_INDEX:
			if effect.index >= 0:
				move_child(effect.actor, effect.index)

	_reconcile_acting_list(before_order, before_acting, effect)
	update_combatant_position()
	_recompute_intents_for_group()


func _swap(actor: Fighter, target: Fighter) -> void:
	pass

func _reconcile_acting_list(
	before_order: Array[Fighter],
	before_acting: Array[Fighter],
	effect: MoveEffect
) -> void:
	# After-move living order (front -> back)
	var after_order: Array[Fighter] = get_combatants()

	# If the group isn't in a turn (or no queue), just rebuild from order
	if before_acting.is_empty():
		acting_fighters = after_order.duplicate()
		_update_pending_turn_glow()
		return

	var current_actor: Fighter = before_acting[0]
	if !current_actor or !is_instance_valid(current_actor) or !after_order.has(current_actor):
		# Current actor got removed / died mid-move; rebuild conservatively
		acting_fighters = after_order.duplicate()
		_update_pending_turn_glow()
		return

	# Who had already acted BEFORE the move?
	var before_acting_set := {}
	for f in before_acting:
		if f:
			before_acting_set[f.get_instance_id()] = true

	var before_acted_set := {}
	for f in before_order:
		if f and !before_acting_set.has(f.get_instance_id()):
			before_acted_set[f.get_instance_id()] = true

	# Rebuild queue:
	# - keep current actor first
	# - include everyone positioned AFTER current actor in after_order
	#   IF they are eligible to still take a turn
	var new_queue: Array[Fighter] = [current_actor]
	var cur_idx := after_order.find(current_actor)

	for i in range(after_order.size()):
		var f := after_order[i]
		if !f or f == current_actor:
			continue

		# Anything that is now BEFORE the current actor is considered "past"
		# to avoid time-paradox turn order changes mid-action.
		if i < cur_idx:
			continue

		var id := f.get_instance_id()
		var already_acted := before_acted_set.has(id)

		if already_acted:
			# Allow a single restore per fighter per group turn, only if effect allows it
			if effect and effect.can_restore_turn and !_restored_turn_this_group_turn.has(id):
				_restored_turn_this_group_turn[id] = true
				new_queue.append(f)
			# else: skip (they already acted)
		else:
			# Not yet acted => keep them
			new_queue.append(f)

	acting_fighters = new_queue
	_update_pending_turn_glow()

func _update_pending_turn_glow() -> void:
	#var pending := {}
	#for f in acting_fighters:
		#if f:
			#pending[f.get_instance_id()] = true
#
	#for f in get_combatants():
		#if f and f.has_method("set_pending_turn_glow"):
			#f.set_pending_turn_glow(pending.has(f.get_instance_id()))
	pass

func get_window_dist() -> float:
	return get_viewport_rect().size.x * 3.0 / 16.0


func get_summon_slot_position(slot_index: int) -> Vector2:
	var p := _get_layout_params()
	
	if p.n_fighters == 0:
		return global_position
	
	var slot := slot_index + 0.5
	var x := _get_x_for_slot(slot)
	return global_position + Vector2(x, 0)


func combatant_died(fighter: Fighter) -> void:
	if fighter is SummonedAlly:
		fighter.discard_summon_reserve_card(deck)
	Events.dead_combatant_data.emit(fighter.combatant_data)
	remove_combatant(fighter)

func turn_reset() -> void:
	for fighter: Fighter in get_combatants():
		fighter.turn_reset()

func _on_turn_taker_action_resolved(turn_taker_who_finished: Fighter) -> void:
	if turn_taker_who_finished != acting_fighters[0]:
		#print("battle_group.gd _on_turn_taker_turn_complete() turn_taker_who_finished is not the acting fighter.")
		return
	turn_taker_who_finished.exit()

func _on_combatant_statuses_applied(proc_type: Status.ProcType, fighter: Fighter) -> void:
	match proc_type:
		Status.ProcType.START_OF_TURN:
			fighter.do_turn()
		Status.ProcType.END_OF_TURN:
			acting_fighters.erase(fighter)
			_next_turn_taker()

func has_ai_behavior(node: Node) -> bool:
	for child in node.get_children():
		if child is NPCAIBehavior:
			return true
	return false

func _recompute_intents_for_group() -> void:
	for fighter: Fighter in get_combatants():
		if has_ai_behavior(fighter):
			for child in fighter.get_children():
				if child is NPCAIBehavior:
					child.plan_next_intent()
					child.refresh_intent_display_only()
