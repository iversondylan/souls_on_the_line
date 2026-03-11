# group_view.gd

class_name GroupView extends Node2D

@export var faces_right: bool = true

# Optional padding knob
@export var window_dist_factor: float = 0.26875

# cid -> view (only those in this group)
var combatants_by_cid: Dictionary = {}
var layout_ctx: GroupLayoutOrder
var _layout_dirty := false

#func register_view(ctx: GroupLayoutOrder) -> void:#v: CombatantView) -> void:
	#if ctx.new_combatant == null:
		#return
	#combatants_by_cid[int(ctx.new_combatant.cid)] = ctx.new_combatant
	#update_layout(ctx)

func unregister_cid(cid: int) -> void:
	combatants_by_cid.erase(int(cid))
	var ctx := GroupLayoutOrder.new()
	ctx.animate_to_position = true
	# ctx.group_index isn't stored on GroupView, so optional:
	# ctx.group_index = ??? (BattleEventDirector knows group index anyway)
	_mark_layout_dirty(ctx)

func set_order(ctx: GroupLayoutOrder) -> void:
	# Reorder child list according to order of cids.
	for i in range(ctx.order.size()):
		var cid := int(ctx.order[i])
		var combatant: CombatantView = combatants_by_cid.get(cid, null)
		if combatant != null and combatant.get_parent() == self:
			move_child(combatant, i)
	_mark_layout_dirty(ctx)

func register_combatant(ctx: GroupLayoutOrder) -> void:
	combatants_by_cid[int(ctx.new_combatant.cid)] = ctx.new_combatant
	_mark_layout_dirty(ctx)

func _mark_layout_dirty(ctx: GroupLayoutOrder) -> void:
	layout_ctx = ctx
	if _layout_dirty:
		return
	_layout_dirty = true
	call_deferred("_flush_layout") # do it once

func _flush_layout() -> void:
	_layout_dirty = false
	var nodes := _get_layout_nodes()
	var slot := 1.0
	for n in nodes:
		var x := _get_x_for_slot(slot, nodes.size())
		# views are Node2D, just position them
		n.set_anchor_position(Vector2(x, 0), layout_ctx)
		#n.position = Vector2(x, 0)
		slot += 1.0
	layout_ctx = null

#func update_layout() -> void:
	

func get_window_dist() -> float:
	return get_viewport_rect().size.x * window_dist_factor

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
	if int(p.n) == 0:
		return 0.0
	return float(p.right) - float(p.increment) * slot if faces_right else float(p.left) + float(p.increment) * slot

func _get_layout_nodes() -> Array[CombatantView]:
	var out: Array[CombatantView] = []
	for c in get_children():
		if c is CombatantView:
			var v := c as CombatantView
			# Only layout “alive” units
			if v.is_alive:
				out.append(v)
	return out

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		var ctx := GroupLayoutOrder.new()
		ctx.animate_to_position = false
		_mark_layout_dirty(ctx)
