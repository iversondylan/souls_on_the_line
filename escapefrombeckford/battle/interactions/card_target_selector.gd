# card_target_selector.gd

class_name CardTargetSelector
extends Node2D

const ARC_POINTS := 8

@onready var area_2d: Area2D = $Area2D
@onready var card_arc: Line2D = $CanvasLayer/CardArc

var current_card: UsableCard
var targeting := false
var _arrow_views: Array[CombatantView] = []

func _ready() -> void:
	area_2d.card_target_selector = self
	Events.card_aim_started.connect(_on_card_aim_started)
	Events.card_aim_ended.connect(_on_card_aim_ended)
	Events.battlefield_aim_started.connect(_on_battlefield_aim_started)
	Events.battlefield_aim_ended.connect(_on_battlefield_aim_ended)

func _process(_delta: float) -> void:
	if not targeting:
		return
	if not is_instance_valid(current_card):
		_end_targeting()
		return

	area_2d.global_position = get_global_mouse_position()
	card_arc.points = _get_points()
	_sync_overlapping_targets()

func _get_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var start := _world_to_arc_local(current_card.global_position)
	var target := _viewport_to_arc_local(get_viewport().get_mouse_position())
	var distance := (target - start)
	
	for i in range(ARC_POINTS):
		var t := (1.0 / ARC_POINTS) * i
		var x := start.x + (distance.x / ARC_POINTS) * i
		var y := start.y + ease_out_cubic(t) * distance.y
		points.append(Vector2(x, y))
	
	points.append(target)
	
	return points

func _world_to_arc_local(point: Vector2) -> Vector2:
	var viewport_point := get_global_transform_with_canvas() * to_local(point)
	return _viewport_to_arc_local(viewport_point)

func _viewport_to_arc_local(point: Vector2) -> Vector2:
	return card_arc.get_global_transform_with_canvas().affine_inverse() * point

func ease_out_cubic(number : float) -> float:
	return 1.0 - pow(1.0 - number, 3.0)

func _on_card_aim_started(card: UsableCard) -> void:
	if not card.card_data.is_single_targeted():
		return
	area_2d.set_collision_mask_value(4, false)
	area_2d.set_collision_mask_value(3, true)
	targeting = true
	area_2d.monitoring = true
	area_2d.monitorable = true
	current_card = card
	_sync_overlapping_targets.call_deferred()
	#card

func _on_card_aim_ended(_card: UsableCard) -> void:
	_end_targeting()

func _on_battlefield_aim_started(card: UsableCard) -> void:
	if not card.card_data.target_type == CardData.TargetType.BATTLEFIELD:
		return
	area_2d.set_collision_mask_value(3, false)
	area_2d.set_collision_mask_value(4, true)
	targeting = true
	area_2d.monitoring = true
	area_2d.monitorable = true
	current_card = card
	_sync_overlapping_targets.call_deferred()

func _on_battlefield_aim_ended(_card: UsableCard) -> void:
	_end_targeting()

func _on_area_2d_area_entered(area: Area2D) -> void:
	#print("card_target_selector.gd _on_area_2d_area_entered()")
	if !current_card or !targeting:
		return
	_sync_overlapping_targets()

func _on_area_2d_area_exited(area: Area2D) -> void:
	#print("card_target_selector.gd _on_area_2d_area_exited()")
	if !current_card or !targeting:
		return
	_sync_overlapping_targets()

func _end_targeting():
	targeting = false
	card_arc.clear_points()
	area_2d.position = Vector2.ZERO
	area_2d.monitoring = false
	area_2d.monitorable = false
	_clear_targeted_arrows()

	if current_card and current_card.battle_view != null and current_card.battle_view.target_arrow != null:
		current_card.battle_view.target_arrow.hide_arrow()

	current_card = null

func _sync_overlapping_targets() -> void:
	if !current_card or !targeting:
		return

	var next_targets: Array[Node] = []
	for area in area_2d.get_overlapping_areas():
		if can_target_area(area):
			next_targets.append(area)

	if !_same_targets(current_card.targets, next_targets):
		current_card.targets.assign(next_targets)
		current_card.update_description()
		_update_battlefield_arrow()

	_sync_targeted_arrows(next_targets)

func _same_targets(a: Array[Node], b: Array[Node]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

func _sync_targeted_arrows(targets: Array[Node]) -> void:
	var next_views: Array[CombatantView] = []
	for target in targets:
		if target is CombatantTargetArea:
			var target_area := target as CombatantTargetArea
			if target_area.combatant_view != null and !next_views.has(target_area.combatant_view):
				next_views.append(target_area.combatant_view)

	for view in _arrow_views:
		if is_instance_valid(view) and !next_views.has(view):
			view.show_targeted_arrow(false)
	for view in next_views:
		if is_instance_valid(view):
			view.show_targeted_arrow(true)

	_arrow_views = next_views

func _clear_targeted_arrows() -> void:
	for view in _arrow_views:
		if is_instance_valid(view):
			view.show_targeted_arrow(false)
	_arrow_views.clear()

func _update_battlefield_arrow():
	if !current_card or !targeting:
		return
	if current_card.card_data.target_type != CardData.TargetType.BATTLEFIELD:
		return
	if current_card.battle_view == null or current_card.battle_view.target_arrow == null:
		return

	var slot_targets: Array[Node] = []
	for t in current_card.targets:
		if t is CombatantAreaLeft or t is BattleSceneAreaLeft:
			slot_targets.append(t)

	if slot_targets.is_empty():
		current_card.battle_view.target_arrow.hide_arrow()
		return

	var insert_index := slot_targets.size() - 1
	var pos := current_card.battle_view.get_summon_slot_position(0, insert_index)
	current_card.battle_view.target_arrow.show_at(pos)

func can_target_area(area: Area2D) -> bool:
	if current_card == null or current_card.card_data == null:
		return false

	if current_card.card_data.target_type == CardData.TargetType.BATTLEFIELD:
		return area is CombatantAreaLeft or area is BattleSceneAreaLeft

	if area is not CombatantTargetArea:
		return false
	if current_card.api == null:
		return false

	var actor_id := int(current_card.api.get_player_id())
	var target_id := int((area as CombatantTargetArea).cid)
	return CardTargeting.is_valid_target(current_card.card_data, actor_id, target_id, current_card.api)
