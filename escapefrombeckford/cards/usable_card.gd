# usable_card.gd

class_name UsableCard extends Node2D

signal card_fan_requested(which_usable_card: UsableCard)
signal mouse_entered(usablecard: UsableCard)
signal mouse_exited(usablecard: UsableCard)

var player: Player : set = _set_player
var battle_scene: BattleScene
var hand: Hand
var actions: Array[CardAction]
var card_name_str: String = "Card Name"
var card_description_str: String = "Card Description"
var cost_red: int = 1
var cost_green: int = 1
var cost_blue: int = 1
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
	Events.n_combatants_changed.connect(_on_n_combatants_changed)
	Events.player_combatant_data_changed.connect(_on_player_combatant_data_changed)
	Events.player_modifier_changed.connect(_on_player_modifier_changed)
	card_state_machine.init(self)

func _input(event: InputEvent) -> void:
	card_state_machine.on_input(event)

	if disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mouse_over():
			Events.hand_card_clicked.emit(self)

func _process(_delta):
	if _is_popped and is_instance_valid(strictly_visuals):
		strictly_visuals.rotation = -rotation

func animate_to_position(new_position: Vector2, new_rotation: float, duration: float, scale: Vector2 = Vector2.ONE, on_finish: Callable = Callable()) -> void:
	#print("usable_card.gd animate_to_position()")
	if tween and is_instance_valid(tween):
		tween.kill()
		tween = null
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	duration = maxf(duration, 0.001)
	tween.tween_property(self, "global_position", new_position,  duration)
	tween.tween_property(self, "rotation_degrees", new_rotation,  duration)
	tween.tween_property(self, "scale", scale,  duration)
	if on_finish.is_valid():
		tween.finished.connect(on_finish, CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func animate_to_rotation(new_rotation: float, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", new_rotation,  duration)

func _set_player(new_player: Player) -> void:
	player = new_player
	if !is_node_ready():
		await ready
	card_state_machine.player = player
	

func _set_card_data(_card_data: CardData) -> void:
	if !is_node_ready():
		await ready
	card_data = _card_data
	card_visuals.card_data = card_data
	_update_graphics()
	update_description()
	playable = is_playable()

func highlight():
	if disabled == false and card_state_machine.current_state is BaseState:
		card_visuals.glow.show()

func unhighlight():
	card_visuals.glow.hide()

func set_selected_visual(on: bool) -> void:
	card_visuals.glow.visible = on

func update_description() -> void:
	card_visuals.description.set_text(get_description())

func get_description() -> String:
	var text := card_data.description
	var resolved := resolve_targets(targets)

	var ctx := CardActionContext.new()
	ctx.player = player
	ctx.player_data = player.combatant_data
	ctx.battle_scene = battle_scene
	ctx.card_data = card_data
	ctx.resolved_target = resolved

	for action: CardAction in card_data.actions:
		var total_slots := TextUtils.count_placeholders(text)

		# If there are no placeholders left, switch to modular append behavior.
		if total_slots <= 0:
			var extra := action.get_modular_description(ctx)
			if extra != null and extra != "":
				# append with a leading space (as requested)
				text += " " + extra
			continue

		var consume := action.description_arity()
		if consume <= 0:
			# This action doesn't consume placeholders; leave text unchanged
			# (modular append happens only when total_slots == 0, handled above)
			continue

		var values := action.get_description_values(ctx)
		# You can keep this assert if you want strict authoring:
		# assert(values.size() == consume)

		# We apply at most the number of placeholders available.
		# If the action returned MORE values than placeholders, that's the only error case.
		var apply_n : int = min(values.size(), total_slots)
		if values.size() > total_slots:
			push_error(
				"UsableCard.get_description(): action returned %s values but only %s placeholders remain. Truncating."
				% [values.size(), total_slots]
			)

		# Build formatting args: fill remaining slots with "%s" so placeholders persist.
		var args: Array = []
		for i in range(apply_n):
			args.append(values[i])

		for i in range(total_slots - apply_n):
			args.append("%s")

		text = text % args

	text = text.replace("{percent}", "%")
	text = TextUtils.percent_to_symbol(text)
	text = TextUtils.end_with_period(text)
	return text



func get_cost() -> Array[int]:
	return [card_data.cost_red, card_data.cost_green, card_data.cost_blue]

func activate() -> bool:
	var resolved_targets := resolve_targets(targets)
	if resolved_targets.fighters.is_empty() and resolved_targets.areas.is_empty():
		return false

	if !player.can_play_card(card_data):
		return false

	var ctx := build_action_context(resolved_targets)

	# detect summon replace need
	var summon_action := _get_first_summon_action()
	if summon_action != null and summon_action.requires_summon_slot():
		var needs_replace := battle_scene.get_n_summoned_allies() >= BattleGroupFriendly.MAX_SOULBOUND
		if needs_replace:
			var effect := summon_action.build_effect(ctx)
			Events.request_summon_replace.emit(self, ctx, effect, summon_action)
			return true
	
	var swap_action := _get_first_swap_action()
	if swap_action != null:
		# We require an initial target (actor) via your targeting rules.
		Events.request_swap_partner.emit(self, ctx, resolved_targets.fighters[0], swap_action)
		return true
	
	# normal commit path
	return commit_play(ctx, null, true)

func _get_first_summon_action() -> SummonAction:
	for action in card_data.actions:
		if action is SummonAction:
			return action
	return null

func _get_first_swap_action() -> CardAction:
	for action in card_data.actions:
		if action is SwapWithTargetAction:
			return action
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

func _on_n_combatants_changed() -> void:
	playable = is_playable()

func _on_player_combatant_data_changed() -> void:
	playable = is_playable()

func _on_player_modifier_changed() -> void:
	card_visuals.set_description(get_description())

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

func resolve_targets(new_targets: Array[Node]) -> CardResolvedTarget:
	
	var result := CardResolvedTarget.new()
	
	if !new_targets:
		return result
	
	match card_data.target_type:
		CardData.TargetType.SELF:
			result.fighters = [player] as Array[Fighter]
		
		CardData.TargetType.BATTLEFIELD:
			#var correct_targets: Array[Fighter] = []
			result.areas.clear()
			for target in new_targets:
				if target is CombatantAreaLeft or target is BattleSceneAreaLeft:
					result.areas.append(target)
			result.insert_index = new_targets.size() - 1
		
		CardData.TargetType.ALLY_OR_SELF:
			#var correct_targets: Array[Fighter] = []
			if new_targets[0] is CombatantTargetArea:
				if new_targets[0].combatant is Player or new_targets[0].combatant is SummonedAlly:
					result.fighters = [new_targets[0].combatant] as Array[Fighter]
		
		CardData.TargetType.ALLY:
			#var correct_targets: Array[Fighter]  = []
			if new_targets[0] is CombatantTargetArea:
				if new_targets[0].combatant is SummonedAlly:
					result.fighters = [new_targets[0].combatant] as Array[Fighter]
		
		CardData.TargetType.SINGLE_ENEMY:
			if new_targets[0] is CombatantTargetArea:
				if new_targets[0].combatant is Enemy:
					result.fighters = [new_targets[0].combatant] as Array[Fighter]
		
		CardData.TargetType.ALL_ENEMIES:
			result.fighters = battle_scene.get_combatants_in_group(1) as Array[Fighter]
		
		CardData.TargetType.EVERYONE:
			result.fighters = battle_scene.get_all_combatants() as Array[Fighter]
	return result

func is_playable() -> bool:
	if !player.can_play_card(card_data):
		return false
	
	#for action in card_data.actions:
		#if action.requires_summon_slot():
			#if battle_scene.get_n_summoned_allies() >= player.combatant_data.max_mana_blue:
				#return false
	#
	return true

func get_fighters(new_targets: Array[Node]) -> Array[Fighter]:
	var attack_targets: Array[Fighter]
	for target in new_targets:
		if target is CombatantTargetArea:
			if target.combatant is Fighter:
				attack_targets.push_back(target.combatant)
	return attack_targets

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

	var target_pos := _home_pos + POP_OFFSET
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


func build_action_context(resolved_targets: CardResolvedTarget) -> CardActionContext:
	var ctx := CardActionContext.new()
	ctx.player = player
	ctx.battle_scene = battle_scene
	ctx.card_data = card_data
	ctx.resolved_target = resolved_targets
	return ctx


func commit_play(ctx: CardActionContext, skip_action: CardAction = null, spend_mana: bool = true) -> bool:
	# Spend mana once
	#print("1")
	if spend_mana:
		ctx.player.spend_mana(ctx.card_data)

	# Execute actions (skipping one if requested)
	var any_action_executed := false
	for action: CardAction in ctx.card_data.actions:
		if skip_action != null and action == skip_action:
			continue
		if action.activate(ctx):
			any_action_executed = true
	#print("2")
	#if !any_action_executed:
		#return false
	#print("3")
	Events.card_played.emit(self)
	_move_to_destination()
	return true


func _move_to_destination() -> void:
	#print("usable_card.gd _move_to_destination()")
	if card_data.deplete:
		hand.deplete_card(hand.remove_card_by_entity(self))
	elif card_data.card_type == CardData.CardType.SUMMON:
		hand.reserve_summon_card(hand.remove_card_by_entity(self))
	else:
		hand.discard_card(hand.remove_card_by_entity(self))
