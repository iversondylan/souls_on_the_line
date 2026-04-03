# usable_card.gd

class_name UsableCard extends Node2D

const MAX_SOULBOUND := 3
const MAX_DEPLETE := 2

signal card_fan_requested(which_usable_card: UsableCard)
signal mouse_entered(usablecard: UsableCard)
signal mouse_exited(usablecard: UsableCard)

#var player_data: PlayerData : set = _set_player
#var battle_scene: BattleScene
var battle_view: BattleView
var sim_host: SimHost
var api: SimBattleAPI

var hand: Hand
var card_name_str: String = "Card Name"
var card_description_str: String = "Card Description"

var cost := 1 #NEW

#var cost_red: int = 1
#var cost_green: int = 1
#var cost_blue: int = 1
var card_data: CardData : set = _set_card_data

@onready var card_visuals: CardVisuals = $CardVisuals

@onready var click_area_area2d: Area2D = $ClickArea
@onready var card_back_sprite2d: Sprite2D = $CardBack
@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []

@onready var strictly_visuals: Node2D = card_visuals.card_strictly_visuals

var _pop_tween: Tween
var _home_pos: Vector2
var _home_scale: Vector2
var _home_rot: float
var _home_cached := false
var _is_popped := false

const POP_OFFSET := Vector2(0, -220)
const POP_SCALE := Vector2(1.35, 1.35)
const POP_DUR := 0.12

var tween: Tween
var playable := true : set = _set_playable
var disabled := false
var selected = false

var interaction: InteractionContext

func _ready() -> void:
	#print_tree_pretty()
	_cache_home()
	Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
	Events.card_aim_ended.connect(_on_card_drag_or_aiming_ended)
	Events.card_drag_ended.connect(_on_card_drag_or_aiming_ended)
	Events.mana_view_update.connect(_mana_changed)
	Events.modify_battle_card.connect(_on_modify_battle_card)
	card_state_machine.init(self)

func _input(event: InputEvent) -> void:
	card_state_machine.on_input(event)

	if disabled:
		return

func _process(_delta):
	if _is_popped and is_instance_valid(strictly_visuals):
		strictly_visuals.rotation = -rotation

func _player_id() -> int:
	if api == null:
		return 0
	return int(api.get_player_id())

func animate_to_position(new_position: Vector2, new_rotation: float, duration: float, _scale: Vector2 = Vector2.ONE, on_finish: Callable = Callable()) -> void:
	#print("usable_card.gd animate_to_position()")
	if tween and is_instance_valid(tween):
		tween.kill()
		tween = null
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	duration = maxf(duration, 0.001)
	tween.tween_property(self, "global_position", new_position,  duration)
	tween.tween_property(self, "rotation_degrees", new_rotation,  duration)
	tween.tween_property(self, "scale", _scale,  duration)
	if on_finish.is_valid():
		tween.finished.connect(on_finish, CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func animate_to_rotation(new_rotation: float, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", new_rotation,  duration)

func _set_card_data(_card_data: CardData) -> void:
	if !is_node_ready():
		await ready
	card_data = _card_data
	card_visuals.card_data = card_data
	cost = int(card_data.get_total_cost()) if card_data != null else 0
	_update_graphics()
	update_description()
	playable = is_playable()

func refresh_from_card_data() -> void:
	if !is_node_ready():
		await ready
	if card_data == null:
		return
	cost = int(card_data.get_total_cost())
	card_visuals.refresh_from_card_data()
	playable = is_playable()

func highlight():
	if disabled == false and card_state_machine.is_in_state(CardState.State.BASE):
		card_visuals.glow.show()

func unhighlight():
	card_visuals.glow.hide()

func set_selected_visual(on: bool) -> void:
	card_visuals.glow.visible = on

func update_description() -> void:
	card_visuals.description.set_text(get_description())

func get_description() -> String:
	if api != null:
		return TextUtils.build_battle_card_description(card_data, api)
	return TextUtils.build_card_description(card_data)



func get_cost() -> int:
	if card_data == null:
		return 0
	return int(card_data.get_total_cost())



func activate() -> bool:
	return begin_execution(
		api,
		sim_host.get_main_runtime(),
		api.get_player_id(),
		resolve_targets(targets),
		{}
	)

func begin_execution(
	_api: SimBattleAPI,
	runtime: SimRuntime,
	source_id: int,
	_targets: CardResolvedTargetView,
	params: Dictionary = {}
) -> bool:
	var ctx := make_card_context(_api, runtime, source_id, _targets, params)
	return runtime.begin_card_execution(ctx)

func make_card_context(
	_api: SimBattleAPI,
	runtime: SimRuntime,
	source_id: int,
	_targets: CardResolvedTargetView,
	params: Dictionary = {}
) -> CardContext:
	var ctx := CardContext.new()
	ctx.api = _api
	ctx.runtime = runtime
	ctx.source_id = source_id
	ctx.card_data = card_data
	ctx.source_card = self
	ctx.target_ids = _targets.target_ids
	ctx.insert_index = _targets.insert_index
	ctx.params = params.duplicate(true)
	return ctx

func _get_summon_preview_data() -> CombatantData:
	# Preferred: ask the summon action for preview data
	for a in card_data.actions:
		if a is SummonAction:
			return a.get_preview_summon_data()
	# Fallback: null => ghost will just be empty
	return null

func _update_graphics():
	if card_visuals.name_label.get_text() != card_data.name:
		card_visuals.name_label.set_text(card_data.name)

func _on_click_area_mouse_entered() -> void:
	card_state_machine.on_mouse_entered()
	mouse_entered.emit(self)

func _on_click_area_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()
	mouse_exited.emit(self)

func _on_drop_point_detector_area_entered(area: Area2D) -> void:
	if !targets.has(area):
		targets.push_back(area)

func _on_drop_point_detector_area_exited(area: Area2D) -> void:
	targets.erase(area)

func _on_card_drag_or_aiming_started(used_card: UsableCard) -> void:
	if used_card == self:
		return
	
	disabled = true

func _set_playable(value: bool) -> void:
	playable = value
	if not playable:
		card_visuals.cost_container.set_modulate(Color(1, 0.5, 0.1, 1))
	else:
		card_visuals.cost_container.set_modulate(Color(1, 1, 1, 1))

func _on_card_drag_or_aiming_ended(_usable_card: UsableCard) -> void:
	disabled = false
	playable = is_playable()

func _mana_changed(_order: ManaViewOrder) -> void:
	playable = is_playable()


func _on_modify_battle_card(card_uid: String, _modified_fields: Dictionary, _reason: String) -> void:
	if card_data == null:
		return
	if String(card_data.uid) != String(card_uid):
		return
	update_description()

func is_mouse_over() -> bool:
	# Get the global mouse position
	var mouse_pos = get_global_mouse_position()
	# Get the Area2D and its CollisionShape2D
	var shape = click_area_area2d.get_node("CollisionShape2D").shape
	if shape == null:
		return false
	# Transform mouse into the shape's local space
	var local_pos = click_area_area2d.to_local(mouse_pos)
	var extents = shape.extents
	return abs(local_pos.x) <= extents.x and abs(local_pos.y) <= extents.y

func resolve_targets(new_targets: Array[Node]) -> CardResolvedTargetView:
	var result := CardResolvedTargetView.new()
	if new_targets == null or new_targets.is_empty() or card_data == null or api == null:
		return result

	var player_id := _player_id()

	match card_data.target_type:
		CardData.TargetType.SELF:
			if player_id > 0:
				result.target_ids.append(player_id)
				var pv = battle_view.get_combatant(player_id) if battle_view != null else null
				if pv != null:
					result.views.append(pv)

		CardData.TargetType.BATTLEFIELD:
			result.areas.clear()
			for t in new_targets:
				if t is CombatantAreaLeft or t is BattleSceneAreaLeft:
					result.areas.append(t)
			#print("BATTLEFIELD result.insert_index = ", new_targets.size() - 1)
			result.insert_index = new_targets.size() - 1

		CardData.TargetType.ALLY_OR_SELF, CardData.TargetType.ALLY, CardData.TargetType.SINGLE_ENEMY:
			if new_targets[0] is CombatantTargetArea:
				var ta := new_targets[0] as CombatantTargetArea
				if ta.combatant_view != null and ta.cid > 0:
					result.views = [ta.combatant_view]
					result.target_ids = PackedInt32Array([int(ta.cid)])

		CardData.TargetType.ALL_ENEMIES:
			var ids := api.get_combatants_in_group(1, false)
			for id in ids:
				var cid := int(id)
				result.target_ids.append(cid)
				var v = battle_view.get_combatant(cid) if battle_view != null else null
				if v != null:
					result.views.append(v)

		CardData.TargetType.EVERYONE:
			var ids0 := api.get_combatants_in_group(0, false)
			var ids1 := api.get_combatants_in_group(1, false)

			for id in ids0:
				var cid := int(id)
				result.target_ids.append(cid)
				var v0 = battle_view.get_combatant(cid) if battle_view != null else null
				if v0 != null:
					result.views.append(v0)

			for id in ids1:
				var cid := int(id)
				result.target_ids.append(cid)
				var v1 = battle_view.get_combatant(cid) if battle_view != null else null
				if v1 != null:
					result.views.append(v1)

	return result

func is_playable() -> bool:
	if card_data == null or api == null:
		return false
	return api.can_pay_card(card_data)

func _cache_home() -> void:
	if _home_cached or strictly_visuals == null:
		return
	_home_pos = strictly_visuals.position
	_home_scale = strictly_visuals.scale
	_home_rot = strictly_visuals.rotation
	_home_cached = true

func enlarge_visuals() -> void:
	if disabled:
		return
	_cache_home()
	if strictly_visuals == null or _is_popped:
		return
	_is_popped = true
	_kill_pop_tween()

	var _target_pos := _home_pos + POP_OFFSET
	var target_rot := -rotation # counter parent (radians)
	_pop_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pop_tween.set_parallel()
	_pop_tween.tween_property(strictly_visuals, "global_position:y", 850, POP_DUR)
	_pop_tween.tween_property(strictly_visuals, "scale", POP_SCALE, POP_DUR)
	_pop_tween.tween_property(strictly_visuals, "rotation", target_rot, POP_DUR)

func reset_visuals() -> void:
	if !_home_cached or strictly_visuals == null or !_is_popped:
		return
	_is_popped = false
	_kill_pop_tween()
	
	_pop_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pop_tween.set_parallel()
	_pop_tween.tween_property(strictly_visuals, "position", _home_pos, POP_DUR)
	_pop_tween.tween_property(strictly_visuals, "scale", _home_scale, POP_DUR)
	_pop_tween.tween_property(strictly_visuals, "rotation", _home_rot, POP_DUR)

func _kill_pop_tween() -> void:
	if _pop_tween and is_instance_valid(_pop_tween):
		_pop_tween.kill()
	_pop_tween = null

func _move_to_destination() -> void:
	#print("usable_card.gd _move_to_destination()")
	if card_data.deplete:
		hand.deplete_card(hand.remove_card_by_entity(self))
	elif card_data.card_type == CardData.CardType.SUMMON:
		hand.reserve_summon_card(hand.remove_card_by_entity(self))
	else:
		hand.discard_card(hand.remove_card_by_entity(self))

func commit_activation() -> void:
	Events.card_played.emit(self)
	_move_to_destination()

func finish_activation(_committed := true) -> void:
	return
