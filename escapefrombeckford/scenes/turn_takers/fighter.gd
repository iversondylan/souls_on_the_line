# fighter.gd

class_name Fighter extends Node2D

signal action_resolved(turn_taker: Fighter)
signal statuses_applied(proc_type: Status.ProcType)
signal damage_taken(ctx: DamageContext)

enum TurnStatus {TURN_PENDING, TURN_ACTIVE, NONE}

@export var battle_group: BattleGroup
@onready var combatant: Combatant = $Combatant
@onready var character_sprite: Sprite2D = combatant.character_sprite
@onready var target_area: CombatantTargetArea = combatant.target_area
@onready var targeted_arrow: Sprite2D = combatant.targeted_arrow
@onready var pending_turn_glow: Sprite2D = combatant.pending_turn_glow
@onready var fade_mark: Sprite2D = combatant.fade_mark
@onready var health_bar: HealthBar = combatant.health_bar
@onready var armor_sprite: Sprite2D = combatant.armor_sprite
@onready var armor_label: Label = combatant.armor_label
@onready var intent_container: IntentContainer = combatant.intent_container
@onready var camera_focus: Node2D = combatant.camera_focus
@onready var area_left: CombatantAreaLeft = combatant.area_left
@onready var damage_number_scn: PackedScene = preload("res://scenes/ui/damage_number.tscn")
@onready var blocked_message_scn: PackedScene = preload("res://scenes/ui/blocked_message.tscn")
@onready var modifier_system: ModifierSystem = $ModifierSystem

var combatant_data: CombatantData : set = _set_combatant_data
var battle_scene: BattleScene : set = _set_battle_scene
var run: Run : set = _set_run
var fighter_tween: Tween
var anchor_position: Vector2# = Vector2(0, 0)
var has_anchor_position: bool = false

func _ready() -> void:
	combatant.target_area_area_entered.connect(_on_target_area_area_entered)
	combatant.target_area_area_exited.connect(_on_target_area_area_exited)
	Events.battle_reset.connect(_battle_reset)
	combatant.statuses_applied.connect(_on_combatant_statuses_applied)
	modifier_system.modifier_changed.connect(_on_modifier_changed)
	target_area.combatant = self
	combatant.fighter = self

func _set_combatant_data(new_data: CombatantData) -> void:
	combatant_data = new_data
	name = combatant_data.name
	combatant.combatant_data = combatant_data
	
	for child in get_children():
		if child is FighterBehavior:
			child._on_combatant_data_set(new_data)

func _set_battle_scene(new_battle_scene: BattleScene) -> void:
	battle_scene = new_battle_scene
	if !is_node_ready():
		await ready
	combatant.battle_scene = battle_scene

func _set_run(new_run) -> void:
	run = new_run
	if !is_node_ready():
		await ready
	modifier_system.run = run

func enter() -> void:
	set_pending_turn_glow(TurnStatus.TURN_ACTIVE)
	Events.fighter_entered_turn.emit(self)
	combatant.status_grid.apply_statuses_by_type(Status.ProcType.START_OF_TURN)
	for child in get_children():
		if child is FighterBehavior:
			child._on_enter()

func exit() -> void:
	combatant.status_grid.apply_statuses_by_type(Status.ProcType.END_OF_TURN)
	for child in get_children():
		if child is FighterBehavior:
			child._on_exit()

func my_group_turn_start() -> void:
	pass

func opposing_group_turn_start() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_opposing_group_turn_start()

func my_group_turn_end() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_group_turn_end()
	combatant.status_grid.clear_group_turn_end_statuses()

func opposing_group_turn_end() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_group_turn_end()

func set_anchor_position(_position: Vector2, animate: bool) -> void:
	anchor_position = _position
	if animate and has_anchor_position:
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", anchor_position, 0.12)
	else:
		position = anchor_position
	has_anchor_position = true

func apply_heal(ctx: HealContext) -> void:
	if !ctx or !is_instance_valid(self) or !is_alive():
		return
	
	ctx.target = self
	var restored_health := combatant_data.heal(ctx)

func apply_damage(ctx: DamageContext) -> void:
	#print("fighter.gd !N!E!W! apply_damage")
	if !ctx or !is_instance_valid(self) or !is_alive():
		return
	
	# Ensure target is set correctly
	ctx.target = self
	ctx.phase = DamageContext.Phase.PRE_MODIFIERS
	
	# Target-side modifiers
	if modifier_system:
		ctx.amount = modifier_system.get_modified_value(ctx.amount, ctx.take_modifier_type)
	
	ctx.amount = maxi(ctx.amount, 0)
	ctx.phase = DamageContext.Phase.POST_MODIFIERS
	
	# Apply to stats (this returns health_loss currently)
	var pre_armor := combatant_data.armor
	var health_loss := combatant_data.take_damage(ctx.amount)
	
	ctx.health_damage = health_loss
	ctx.armor_damage = maxi(mini(ctx.amount, pre_armor), 0)
	ctx.was_lethal = (combatant_data.health <= 0)
	
	ctx.phase = DamageContext.Phase.APPLIED
	
	# Immediate reactions (synchronous)
	damage_taken.emit(ctx)
	combatant.status_grid.on_damage_taken(ctx)
	
	# visuals
	Shaker.shake(self, 16, 0.15)
	_spawn_damage_number_or_block(ctx)
	
	if ctx.was_lethal:
		die()

func _spawn_damage_number_or_block(ctx: DamageContext) -> void:
	if ctx.health_damage > 0:
		var damage_number: DamageNumber = damage_number_scn.instantiate()
		add_child(damage_number)
		damage_number.animate_and_vanish(ctx.health_damage, combatant_data.height)
	else:
		var blocked_message: BlockedMessage = blocked_message_scn.instantiate()
		add_child(blocked_message)
		blocked_message.animate_and_vanish(combatant_data.height)

func add_armor(amount: int):
	combatant_data.add_armor(amount)

##for future: death must cancel pending action resolution
func die():
	combatant_data.alive = false
	print(name, " died")
	combatant.status_grid.end_non_self_statuses()
	
	battle_group.update_combatant_position()
	var death_tween: Tween = create_tween()
	death_tween.tween_property(character_sprite, "modulate", Color.BLACK, 0.3)
	death_tween.tween_callback(
		func():
			battle_group.combatant_died(self)
				)
	for child in get_children():
		if child is FighterBehavior:
			child._on_die()

func do_turn() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_do_turn()

func can_play_card(card_data: CardData) -> bool:
	return combatant_data.can_play_card(card_data)

func spend_mana(card_data: CardData) -> bool:
	print("fighter.gd spend_mana()")
	if combatant_data.spend_mana(card_data):
		return true
	else:
		return false

func discard_summon_reserve_card(_deck: Deck) -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_discard_summon_reserve_card(_deck)

func reset():
	combatant_data.reset_armor()
	combatant_data.reset_mana()
	combatant_data.reset_health()
	#Events.auras_requested.emit(self)

func _battle_reset() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_battle_reset()

func turn_reset() -> void:
	combatant_data.reset_armor()
	combatant_data.reset_mana()

func _on_target_area_area_entered(area: Area2D) -> void:
	if area is not CardTargetSelectorArea:
		return
	match area.card_target_selector.current_card.card_data.target_type:
		CardData.TargetType.ALLY_OR_SELF:
			if self is SummonedAlly or self is Player:
				show_targeted_arrow()
		CardData.TargetType.ALLY:
			if self is SummonedAlly:
				show_targeted_arrow()
		CardData.TargetType.SINGLE_ENEMY:
			if self is Enemy:
				show_targeted_arrow()

func _on_target_area_area_exited(_area: Area2D) -> void:
	hide_targeted_arrow()

func has_status(status_id: String) -> bool:
	return combatant.status_grid._has_status(status_id)

func info_visible(visibility: bool) -> void:
	combatant.info_visible(visibility)

func is_alive() -> bool:
	if !is_node_ready() or !combatant_data:
		return true
	var alive: bool = combatant_data.is_alive()
	return alive

func show_targeted_arrow() -> void:
	targeted_arrow.show()

func hide_targeted_arrow() -> void:
	targeted_arrow.hide()

func set_pending_turn_glow(status: TurnStatus) -> void:
	match status:
		TurnStatus.TURN_ACTIVE:
			pending_turn_glow.show()
			# Unmodulated
			pending_turn_glow.modulate = Color(1.0, 0.65, 0.25)

		TurnStatus.TURN_PENDING:
			pending_turn_glow.show()
			# Cool it toward blue while preserving intensity
			pending_turn_glow.modulate = Color(0.45, 0.65, 1.0)

		TurnStatus.NONE:
			pending_turn_glow.hide()

func set_fade_mark(show_it: bool) -> void:
	if show_it:
		fade_mark.show()
	else:
		fade_mark.hide()

func resolve_action() -> void:
	action_resolved.emit(self)

func _on_combatant_statuses_applied(proc_type: Status.ProcType) -> void:
	statuses_applied.emit(proc_type)

func _on_modifier_changed() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child.update_action_intent()
			child._on_modifier_changed()

func get_modifier_tokens() -> Array[ModifierToken]:
	if !battle_scene:
		return []
	return battle_scene.get_modifier_tokens_for(self)

func modify_target(ctx: AttackTargetContext) -> void:
	## Only apply if this fighter is marked.
	if !is_marked():
		return
	if !is_alive():
		return
	## Check that the attack is targeting this fighter's side.
	if !_is_attack_targeting_us(ctx):
		return
	if ctx.params.get(NPCKeys.ATTACK_MODE) != NPCAttackSequence.ATTACK_MODE_RANGED:
		return
	## Redirect final target to this fighter if it's not multi-target.
	if !ctx.final_targets.has(self) and ctx.is_single_target_intent:
		ctx.final_targets = [self]

func _is_attack_targeting_us(ctx: AttackTargetContext) -> bool:
	# Source and self must be on opposite sides.
	return ctx.source.get_parent() != get_parent()

func is_marked() -> bool:
	return combatant.status_grid._has_status(PinpointStatus.ID)
