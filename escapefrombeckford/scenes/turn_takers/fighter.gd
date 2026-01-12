# fighter.gd
class_name Fighter extends Node2D

signal action_resolved(turn_taker: Fighter)
signal statuses_applied(proc_type: Status.ProcType)

@export var battle_group: BattleGroup
@onready var combatant: Combatant = $Combatant
@onready var character_sprite: Sprite2D = combatant.character_sprite
@onready var target_area: CombatantTargetArea = combatant.target_area
@onready var targeted_arrow: Sprite2D = combatant.targeted_arrow
@onready var health_bar: HealthBar = combatant.health_bar
@onready var armor_sprite: Sprite2D = combatant.armor_sprite
@onready var armor_label: Label = combatant.armor_label
@onready var intent_container: IntentContainer = combatant.intent_container
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
	combatant.status_grid.apply_statuses_by_type(Status.ProcType.START_OF_TURN)
	for child in get_children():
		if child is FighterBehavior:
			child._on_enter()

func exit() -> void:
	combatant.status_grid.apply_statuses_by_type(Status.ProcType.END_OF_TURN)
	for child in get_children():
		if child is FighterBehavior:
			child._on_exit()

func set_anchor_position(_position: Vector2, animate: bool) -> void:
	anchor_position = _position
	if animate and has_anchor_position:
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", anchor_position, 0.12)
	else:
		position = anchor_position
	has_anchor_position = true

func take_damage(n_damage: int, modifier_type: Modifier.Type):
	var modified_damage := modifier_system.get_modified_value(n_damage, modifier_type)
	if combatant_data.check_lethal(modified_damage):
		combatant_data.alive = false
		battle_group.update_combatant_position()
	var tween: Tween = create_tween()
	tween.tween_callback(Shaker.shake.bind(self, 16, 0.15))
	tween.tween_interval(0.2)
	tween.tween_callback(take_damage_part_2.bind(modified_damage))

func take_damage_part_2(n_damage: int) -> void:
	var health_damage := combatant_data.take_damage(n_damage)
	if health_damage > 0:
		var damage_number: DamageNumber = damage_number_scn.instantiate()
		add_child(damage_number)
		damage_number.animate_and_vanish(health_damage, combatant_data.height)
	else:
		var blocked_message: BlockedMessage = blocked_message_scn.instantiate()
		add_child(blocked_message)
		blocked_message.animate_and_vanish(combatant_data.height)
	if combatant_data.health <= 0:
		die()

func heal(n_heal: int) -> void:
	combatant_data.heal(n_heal)

func add_armor(amount: int):
	combatant_data.add_armor(amount)

##for future: death must cancel pending action resolution
func die():
	combatant_data.alive = false
	
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

func traverse_player() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_traverse_player()

func can_play_card(card_data: CardData) -> bool:
	return combatant_data.can_play_card(card_data)

func spend_mana(card_data: CardData) -> bool:
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
