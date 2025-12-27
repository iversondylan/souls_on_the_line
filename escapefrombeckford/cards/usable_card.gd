class_name UsableCard extends Node2D

signal reparent_requested(which_usable_card: UsableCard)
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
var original_index := 0

@onready var state: Label = $State
@onready var card_visuals: CardVisuals = $CardVisuals

@onready var click_area_area2d: Area2D = $ClickArea
@onready var card_back_sprite2d: Sprite2D = $CardBack
@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []

var tween: Tween
var playable := true : set = _set_playable
var disabled := false
var selected = false

func _ready() -> void:
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

func animate_to_position(new_position: Vector2, new_rotation: float, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(self, "global_position", new_position,  duration)
	tween.tween_property(self, "rotation_degrees", new_rotation,  duration)

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
		var consume := action.description_arity()
		
		if consume == 0:
			continue
		
		assert(total_slots >= consume)
		
		var values := action.get_description_values(ctx)
		
		assert(values.size() == consume)
		
		# Fill remaining slots with "%s" to preserve them
		
		var args: Array = []
		for v in values:
			args.append(v)
		
		for i in range(total_slots - consume):
			args.append("%s")
		
		text = text % args
	text = TextUtils.percent_to_symbol(text)
	return text

func set_usable_card_z_index(index: int):
	z_index = index

func get_cost() -> Array[int]:
	return [card_data.cost_red, card_data.cost_green, card_data.cost_blue]

func activate() -> bool:
	# 1. Resolve targets ONCE
	var resolved_targets: CardResolvedTarget = resolve_targets(targets)
	if resolved_targets.fighters.is_empty() and resolved_targets.areas.is_empty():
		return false

	# 2. Check playability (safety guard)
	if !player.can_play_card(card_data):
		return false

	# 3. Spend mana ONCE (not per action)
	print("spending mana")
	player.spend_mana(card_data)

	# 4. Build context
	#var resolved := resolve_targets(targets)
	#if resolved_targets.fighters.is_empty() and !resolved_targets.is_battlefield:
		#return false
	print("making context")
	var ctx := CardActionContext.new()
	ctx.player = player
	ctx.battle_scene = battle_scene
	ctx.card_data = card_data
	ctx.resolved_target = resolved_targets
	
	# 5. Execute actions in order
	var any_action_executed := false
	for action: CardAction in card_data.actions:
		print("about to activate an action")
		if action.activate(ctx):
			any_action_executed = true

	# 6. If nothing happened, refund / abort
	if !any_action_executed:
		return false

	# 7. Emit event
	Events.card_played.emit(self)

	# 8. Handle card destination
	if card_data.deplete or card_data.card_type == CardData.CardType.POWER:
		hand.deplete_card(hand.remove_card_by_entity(self))
	elif card_data.card_type == CardData.CardType.SUMMON:
		hand.reserve_summon_card(hand.remove_card_by_entity(self))
	else:
		hand.discard_card(hand.remove_card_by_entity(self))

	return true

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
	#var area = $ClickArea   # adjust path if your Area2D has a different name
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
			result.fighters.clear()
			result.fighters.append(player)# = [player] as Array[Fighter]
		
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
					result.fighters.clear()
					result.fighters.append(new_targets[0].combatant)
					#result.fighters = [new_targets[0].combatant] as Array[Fighter]
		
		CardData.TargetType.ALLY:
			#var correct_targets: Array[Fighter]  = []
			if new_targets[0] is CombatantTargetArea:
				if new_targets[0].combatant is SummonedAlly:
					result.fighters.clear()
					result.fighters.append(new_targets[0].combatant)
					#result.fighters = [new_targets[0].combatant] as Array[Fighter]
		
		CardData.TargetType.SINGLE_ENEMY:
			if new_targets[0] is CombatantTargetArea:
				if new_targets[0].combatant is Enemy:
					result.fighters.clear()
					result.fighters.append(new_targets[0].combatant)
		
		CardData.TargetType.ALL_ENEMIES:
			result.fighters.clear()
			result.fighters.append(battle_scene.get_combatants_in_group(1))# = battle_scene.get_combatants_in_group(1) as Array[Fighter]
		
		CardData.TargetType.EVERYONE:
			result.fighters.clear()
			result.fighters.append(battle_scene.get_all_combatants())# = battle_scene.get_all_combatants() as Array[Fighter]
	return result

func is_playable() -> bool:
	if !player.can_play_card(card_data):
		return false
	
	for action in card_data.actions:
		if action.requires_summon_slot:
			if battle_scene.get_n_summoned_allies() >= player.combatant_data.max_mana_blue:
				return false
	
	return true

func get_fighters(new_targets: Array[Node]) -> Array[Fighter]:
	var attack_targets: Array[Fighter]
	for target in new_targets:
		if target is CombatantTargetArea:
			if target.combatant is Fighter:
				attack_targets.push_back(target.combatant)
	return attack_targets
