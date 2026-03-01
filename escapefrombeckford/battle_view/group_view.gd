# group_view.gd

class_name GroupView extends Node2D

@export var faces_right: bool = true

# Optional padding knob
@export var window_dist_factor: float = 0.26875

# cid -> view (only those in this group)
var combatants_by_cid: Dictionary = {}
var _layout_dirty := false

func register_view(v: CombatantView) -> void:
	if v == null:
		return
	combatants_by_cid[int(v.cid)] = v
	update_layout()

func unregister_cid(cid: int) -> void:
	combatants_by_cid.erase(int(cid))
	update_layout()

func set_order(order: Array) -> void:
	# Reorder child list according to order of cids.
	for i in range(order.size()):
		var cid := int(order[i])
		var combatant: CombatantView = combatants_by_cid.get(cid, null)
		if combatant != null and combatant.get_parent() == self:
			move_child(combatant, i)
	update_layout()

func register_combatant(c: CombatantView) -> void:
	combatants_by_cid[int(c.cid)] = c
	_mark_layout_dirty()

func _mark_layout_dirty() -> void:
	if _layout_dirty:
		return
	_layout_dirty = true
	call_deferred("_flush_layout") # do it once

func _flush_layout() -> void:
	_layout_dirty = false
	update_layout()

func update_layout() -> void:
	var nodes := _get_layout_nodes()
	var slot := 1.0
	for n in nodes:
		var x := _get_x_for_slot(slot, nodes.size())
		# views are Node2D, just position them
		n.position = Vector2(x, 0)
		slot += 1.0

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

func _get_layout_nodes() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for c in get_children():
		if c is Node2D:
			out.append(c)
	return out

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_mark_layout_dirty()
