# battle_group.gd
class_name BattleGroup extends Node2D

@export var faces_right: bool = true
@onready var preview_layer: Node2D = $PreviewLayer

var battle_scene: BattleScene
var deck: Deck
var run: Run

var acting_fighters: Array[Fighter] = []
var _restored_turn_this_group_turn: Dictionary = {} # int instance_id -> true

var _preview_node: Node2D = null
var _preview_index: int = -1

func reset_npc_actions() -> void:
	for child in get_combatants():
		if has_ai_behavior(child):
			child.current_action = null
			#child.update_action()

func start_turn() -> void:
	if get_combatants().is_empty():
		print("battle_group.gd start_turn() ERROR: stuck with no fighters")
		return
	_restored_turn_this_group_turn.clear()
	acting_fighters.clear()
	
	for fighter: Fighter in get_combatants():
		acting_fighters.append(fighter)
	_update_pending_turn_glow()
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
	for child in get_children():
		if child is Fighter and child.is_alive():
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
	for combatant in get_combatants():
		if !acting_fighters.has(combatant):
			acted += 1
	if rank - acted > 0:
		acting_fighters.insert(rank - acted, fighter)
	_update_pending_turn_glow()

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
	_update_pending_turn_glow()
	if get_combatants().is_empty():
		Events.battle_group_empty.emit(self)
	
	if !dead_fighter_acting:
		return
	
	
	if self is BattleGroupEnemy:
		if BattleController.current_state == BattleController.BattleState.ENEMY_TURN:
			_next_turn_taker()
	elif self is BattleGroupFriendly:
		if BattleController.current_state == BattleController.BattleState.FRIENDLY_TURN:
			_next_turn_taker()

func combatant_died(fighter: Fighter) -> void:
	if fighter is SummonedAlly:
		fighter.discard_summon_reserve_card(deck)
	Events.dead_combatant_data.emit(fighter.combatant_data)
	remove_combatant(fighter)

func combatant_faded(fighter: Fighter) -> void:
	if fighter is SummonedAlly:
		fighter.fade()
		fighter.discard_summon_reserve_card(deck)
	remove_combatant(fighter)

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

func _get_layout_params(layout_count: int) -> Dictionary:
	var window_dist := get_window_dist()
	var left_bound := -window_dist
	var right_bound := window_dist

	var n := layout_count
	var increment := 0.0
	if n > 0:
		increment = (right_bound - left_bound) / (n + 1)

	return {"left": left_bound, "right": right_bound, "increment": increment, "n": n}

func _get_x_for_slot(slot: float, layout_count: int) -> float:
	var p := _get_layout_params(layout_count)
	if p.n == 0:
		return 0.0
	#return faces_right ? p.right - p.increment * slot : p.left + p.increment * slot
	return p.right - p.increment * slot if faces_right else p.left + p.increment * slot

func update_combatant_position():
	var nodes := _get_layout_nodes()
	var slot := 1.0
	for n in nodes:
		var x := _get_x_for_slot(slot, nodes.size())
		if n is Fighter:
			(n as Fighter).set_anchor_position(Vector2(x, 0), true)
		else:
			n.position = Vector2(x, 0)
		slot += 1.0



func _get_layout_nodes() -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for f in get_combatants():
		nodes.append(f)
	if _preview_node:
		nodes.insert(clampi(_preview_index, 0, nodes.size()), _preview_node)
	return nodes

#func update_combatant_position():
	#var nodes := _get_layout_nodes()
	#var slot := 1.0
	#for n in nodes:
		#var x := _get_x_for_slot(slot)
		#if n is Fighter:
			#(n as Fighter).set_anchor_position(Vector2(x, 0), true)
		#else:
			#n.position = Vector2(x, 0)
		#slot += 1.0

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
	if actor == null or target == null:
		return
	if !is_instance_valid(actor) or !is_instance_valid(target):
		return
	if actor == target:
		return
	if actor.get_parent() != self or target.get_parent() != self:
		return

	var a_idx := actor.get_index()
	var t_idx := target.get_index()
	if a_idx == t_idx:
		return

	# Swap child indices safely.
	# After first move, the other index may shift, so adjust.
	move_child(actor, t_idx)

	if a_idx < t_idx:
		# actor moved forward in the list, target shifted left by 1
		move_child(target, a_idx)
	else:
		# actor moved backward, target index unchanged
		move_child(target, a_idx)


func _reconcile_acting_list(
	before_order: Array[Fighter],
	before_acting: Array[Fighter],
	effect: MoveEffect
) -> void:
	var after_order := get_combatants()

	if _should_rebuild_from_scratch(before_acting, after_order):
		acting_fighters = after_order.duplicate()
		_update_pending_turn_glow()
		return

	var current_actor := before_acting[0]

	var before_acted_set := _build_before_acted_set(
		before_order,
		before_acting
	)

	acting_fighters = _build_reconciled_queue(
		current_actor,
		after_order,
		before_acted_set,
		effect
	)

	_update_pending_turn_glow()


func _should_rebuild_from_scratch(
	before_acting: Array[Fighter],
	after_order: Array[Fighter]
) -> bool:
	if before_acting.is_empty():
		return true

	var current_actor := before_acting[0]
	if !current_actor:
		return true
	if !is_instance_valid(current_actor):
		return true
	if !after_order.has(current_actor):
		return true

	return false


func _build_before_acted_set(
	before_order: Array[Fighter],
	before_acting: Array[Fighter]
) -> Dictionary:
	var acting_set := {}
	for f in before_acting:
		if f:
			acting_set[f.get_instance_id()] = true

	var acted_set := {}
	for f in before_order:
		if f and !acting_set.has(f.get_instance_id()):
			acted_set[f.get_instance_id()] = true

	return acted_set

func _build_reconciled_queue(
	current_actor: Fighter,
	after_order: Array[Fighter],
	before_acted_set: Dictionary,
	effect: MoveEffect
) -> Array[Fighter]:
	var queue: Array[Fighter] = [current_actor]
	var cur_idx := after_order.find(current_actor)

	for i in range(cur_idx + 1, after_order.size()):
		var f := after_order[i]
		if !f:
			continue

		var id := f.get_instance_id()
		var already_acted := before_acted_set.has(id)

		if already_acted:
			if _can_restore_turn(f, effect):
				queue.append(f)
		else:
			queue.append(f)

	return queue

func _can_restore_turn(fighter: Fighter, effect: MoveEffect) -> bool:
	if !effect:
		return false
	if !effect.can_restore_turn:
		return false

	var id := fighter.get_instance_id()
	if _restored_turn_this_group_turn.has(id):
		return false

	_restored_turn_this_group_turn[id] = true
	return true


func _update_pending_turn_glow() -> void:
	for f: Fighter in get_combatants():
		if acting_fighters and f == acting_fighters[0]:
			f.set_pending_turn_glow(Fighter.TurnStatus.TURN_ACTIVE)
		else:
			f.set_pending_turn_glow(Fighter.TurnStatus.TURN_PENDING if acting_fighters.has(f) else Fighter.TurnStatus.NONE)

func set_preview(node: Node2D, insert_index: int) -> void:
	# remove old preview
	if _preview_node and is_instance_valid(_preview_node):
		_preview_node.queue_free()

	_preview_node = node
	_preview_index = insert_index

	# IMPORTANT: actually add it to the tree
	preview_layer.add_child(_preview_node)

	update_combatant_position()

func clear_preview() -> void:
	if _preview_node and is_instance_valid(_preview_node):
		_preview_node.queue_free()

	_preview_node = null
	_preview_index = -1
	update_combatant_position()


func get_window_dist() -> float:
	return get_viewport_rect().size.x * 0.26875


func get_summon_slot_position(slot_index: int) -> Vector2:
	var nodes := _get_layout_nodes()
	var layout_count := nodes.size()

	if layout_count == 0:
		return global_position

	var slot := float(slot_index) + 0.5
	var x := _get_x_for_slot(slot, layout_count)
	return global_position + Vector2(x, 0)



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
			_update_pending_turn_glow()
			_next_turn_taker()

func has_ai_behavior(node: Node) -> bool:
	for child in node.get_children():
		if child is NPCAIBehavior:
			return true
	return false

func _recompute_intents_for_group() -> void:
	#print("battle_group.gd _recompute_intents_for_group()")
	for fighter: Fighter in get_combatants():
		if has_ai_behavior(fighter):
			for child in fighter.get_children():
				if child is NPCAIBehavior:
					child.sync_intent()
