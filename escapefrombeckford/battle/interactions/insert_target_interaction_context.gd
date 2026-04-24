# insert_target_interaction_context.gd

class_name InsertTargetInteractionContext extends EscrowCardInteractionContext

const SLOT_RADIUS := 40.0
const SLOT_DIAMOND := 18.0
const SLOT_COLOR := Color(0.55, 0.8, 1.0, 0.32)
const SLOT_HOVER_COLOR := Color(1.0, 0.9, 0.45, 0.5)

var resolving := false
var mover_id: int = 0
var mover_group_index: int = -1
var mover_current_index: int = -1
var before_order_ids: PackedInt32Array = PackedInt32Array()

var _slot_root: Node2D = null
var _slot_areas: Array[Area2D] = []
var _slot_gap_indices: Dictionary = {}
var _slot_polygons: Dictionary = {}
var _slot_positions: Dictionary = {}

func get_interaction_kind() -> StringName:
	return &"insert_target"

func request_open() -> bool:
	if card_ctx == null or card_ctx.target_ids.is_empty():
		return false
	mover_id = int(card_ctx.target_ids[0])
	if mover_id <= 0:
		return false
	return _evaluate_interaction_gate(
		EncounterGateRequest.Kind.OPEN_CARD_INTERACTION,
		PackedInt32Array([mover_id])
	)

func enter() -> void:
	resolving = false
	handler.lock_for_modal()

	var battle_view: BattleView = handler.battle.battle_view if handler != null and handler.battle != null else null
	if battle_view == null or card_ctx == null:
		handler.end_active_context()
		return

	var mover_view := battle_view.get_combatant(mover_id)
	if mover_view == null or !is_instance_valid(mover_view):
		handler.end_active_context()
		return

	mover_group_index = int(mover_view.group_index)
	before_order_ids = _get_group_order(card_ctx.api, mover_group_index)
	mover_current_index = before_order_ids.find(mover_id)
	if mover_group_index < 0 or mover_current_index == -1:
		handler.end_active_context()
		return

	mover_view.show_targeted_arrow(true)
	handler.prompt_show("Choose where to move this unit.", "Cancel")
	_create_slot_overlay(battle_view, mover_view)

func exit() -> void:
	var battle_view: BattleView = handler.battle.battle_view if handler != null and handler.battle != null else null
	if battle_view != null:
		battle_view.target_arrow.hide_arrow()
		var mover_view := battle_view.get_combatant(mover_id)
		if mover_view != null and is_instance_valid(mover_view):
			mover_view.show_targeted_arrow(false)

	for area in _slot_areas:
		if area != null and is_instance_valid(area):
			area.queue_free()
	_slot_areas.clear()
	_slot_gap_indices.clear()
	_slot_polygons.clear()
	_slot_positions.clear()

	if _slot_root != null and is_instance_valid(_slot_root):
		_slot_root.queue_free()
	_slot_root = null

	before_order_ids = PackedInt32Array()
	mover_group_index = -1
	mover_current_index = -1
	resolving = false
	handler.unlock_from_modal()

func on_primary() -> void:
	if resolving:
		return
	if card_ctx != null and card_ctx.runtime != null:
		card_ctx.runtime.cancel_preflight_interaction(card_ctx, action_index)
	handler.end_active_context()

func _create_slot_overlay(battle_view: BattleView, mover_view: CombatantView) -> void:
	_slot_root = Node2D.new()
	_slot_root.name = "InsertTargetSlots"
	battle_view.add_child(_slot_root)

	for gap_index in range(before_order_ids.size() + 1):
		if gap_index == mover_current_index or gap_index == mover_current_index + 1:
			continue
		_add_slot_target(battle_view, gap_index)

	if _slot_areas.is_empty():
		mover_view.show_targeted_arrow(false)
		handler.end_active_context()

func _add_slot_target(battle_view: BattleView, gap_index: int) -> void:
	var anchor := Node2D.new()
	anchor.name = "InsertSlot_%d" % gap_index
	anchor.global_position = battle_view.get_summon_slot_position(mover_group_index, gap_index)
	_slot_root.add_child(anchor)

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, -SLOT_DIAMOND),
		Vector2(SLOT_DIAMOND, 0),
		Vector2(0, SLOT_DIAMOND),
		Vector2(-SLOT_DIAMOND, 0),
	])
	poly.color = SLOT_COLOR
	anchor.add_child(poly)

	var area := Area2D.new()
	area.collision_layer = 8
	area.input_pickable = true
	anchor.add_child(area)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = SLOT_RADIUS
	shape.shape = circle
	area.add_child(shape)

	area.mouse_entered.connect(_on_slot_mouse_entered.bind(area))
	area.mouse_exited.connect(_on_slot_mouse_exited.bind(area))
	area.input_event.connect(_on_slot_input_event.bind(area))

	_slot_areas.append(area)
	_slot_gap_indices[area] = int(gap_index)
	_slot_polygons[area] = poly
	_slot_positions[area] = anchor.global_position

func _on_slot_mouse_entered(area: Area2D) -> void:
	var battle_view: BattleView = handler.battle.battle_view if handler != null and handler.battle != null else null
	if battle_view == null or area == null or !_slot_positions.has(area):
		return
	var poly := _slot_polygons.get(area, null) as Polygon2D
	if poly != null:
		poly.color = SLOT_HOVER_COLOR
	battle_view.target_arrow.show_at(_slot_positions[area])

func _on_slot_mouse_exited(area: Area2D) -> void:
	var battle_view: BattleView = handler.battle.battle_view if handler != null and handler.battle != null else null
	var poly := _slot_polygons.get(area, null) as Polygon2D
	if poly != null:
		poly.color = SLOT_COLOR
	if battle_view != null:
		battle_view.target_arrow.hide_arrow()

func _on_slot_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, area: Area2D) -> void:
	if event == null or !event.is_action_pressed("mouse_click"):
		return
	var gap_index := int(_slot_gap_indices.get(area, -1))
	_confirm_gap(gap_index)

func _confirm_gap(gap_index: int) -> void:
	if resolving:
		return
	var insert_index := _gap_to_insert_index(gap_index)
	if insert_index < 0:
		return
	if !_evaluate_interaction_gate(
		EncounterGateRequest.Kind.CONFIRM_CARD_INTERACTION,
		PackedInt32Array([mover_id]),
		insert_index
	):
		return

	resolving = true
	var payload := {
		Keys.MOVE_UNIT_ID: mover_id,
		Keys.INSERT_INDEX: insert_index,
		Keys.WINDUP_ORDER_IDS: before_order_ids,
	}
	if card_ctx != null and card_ctx.runtime != null:
		card_ctx.runtime.complete_preflight_interaction_and_continue(card_ctx, action_index, payload)
	handler.end_active_context()

func _gap_to_insert_index(gap_index: int) -> int:
	if gap_index < 0:
		return -1
	if gap_index == mover_current_index or gap_index == mover_current_index + 1:
		return -1
	if gap_index < mover_current_index:
		return gap_index
	return gap_index - 1

func _get_group_order(api: SimBattleAPI, group_index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if api == null or group_index < 0:
		return out
	var ids := api.get_combatants_in_group(group_index, false)
	for id in ids:
		out.append(int(id))
	return out
