# fighter.gd

class_name Fighter extends Node2D

signal action_resolved(turn_taker: Fighter)
signal status_proc_finished(proc_type: Status.ProcType)

var last_status_proc_finished: int = -1
var last_status_proc_tick: int = 0

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


var combatant_data: CombatantData : set = _set_combatant_data
var status_system: StatusSystem
var modifier_system: ModifierSystem
var state: FighterState
var battle_scene: BattleScene : set = _set_battle_scene
var run: Run : set = _set_run
var fighter_tween: Tween
var anchor_position: Vector2# = Vector2(0, 0)
var has_anchor_position: bool = false
var combat_id: int
#var dying: bool = false

func _ready() -> void:
	if !status_system:
		status_system = StatusSystem.new(self)
		if run and run.status_catalog:
			status_system.catalog = run.status_catalog
	if combatant and combatant.status_grid:
		combatant.status_grid.bind_system(status_system, self)
	
	if !modifier_system:
		modifier_system = ModifierSystem.new(self)
	
	combatant.target_area_area_entered.connect(_on_target_area_area_entered)
	combatant.target_area_area_exited.connect(_on_target_area_area_exited)
	Events.battle_reset.connect(_battle_reset)
	combatant.statuses_applied.connect(_on_combatant_statuses_applied)
	modifier_system.modifier_changed.connect(_on_modifier_changed)
	target_area.combatant = self
	combatant.fighter = self

func _set_combatant_data(new_data: CombatantData) -> void:
	combatant_data = new_data
	combatant_data.combat_id = combat_id
	if state:
		state.data = combatant_data
	name = combatant_data.name
	combatant.combatant_data = combatant_data
	if battle_scene and battle_scene.api and combatant_data:
		if not combatant_data.combatant_data_changed.is_connected(_on_data_changed):
			combatant_data.combatant_data_changed.connect(_on_data_changed)
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
	if run.status_catalog and status_system:
		status_system.catalog = run.status_catalog

func enter() -> void:
	#print("fighter.gd enter() name: ", name)
	set_pending_turn_glow(TurnStatus.TURN_ACTIVE)
	Events.fighter_entered_turn.emit(self)
	for child in get_children():
		if child is FighterBehavior:
			child._on_enter()

func exit() -> void:
	#print("fighter.gd exit() name: ", name)
	for child in get_children():
		if child is FighterBehavior:
			child._on_exit()

func _emit_status_proc_finished(proc_type: int) -> void:
	last_status_proc_finished = proc_type
	last_status_proc_tick += 1
	status_proc_finished.emit(proc_type)

func my_group_turn_start() -> void:
	pass
	#combatant.status_grid.clear_group_turn_start_statuses()

func opposing_group_turn_start() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_opposing_group_turn_start()

func my_group_turn_end() -> void:
	for child in get_children():
		if child is FighterBehavior:
			child._on_group_turn_end()
	#combatant.status_grid.clear_group_turn_end_statuses()

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
	if !ctx:
		return

	# Always ensure ids
	ctx.target = self
	ctx.target_id = combat_id
	if ctx.source and ctx.source_id == 0:
		ctx.source_id = ctx.source.combat_id

	if battle_scene and battle_scene.api:
		battle_scene.api.resolve_heal(ctx)
		return

	push_warning("Fighter.apply_heal called without battle_scene.api")


func apply_damage(ctx: DamageContext) -> void:
	if !ctx:
		return

	# Always ensure ids
	ctx.target = self
	ctx.target_id = combat_id
	if ctx.source and ctx.source_id == 0:
		ctx.source_id = ctx.source.combat_id

	# Preferred path: API owns damage + death + visuals
	if battle_scene and battle_scene.api:
		battle_scene.api.resolve_damage(ctx)
		return

	# Fallback: do nothing (or keep a private legacy impl if you want)
	push_warning("Fighter.apply_damage called without battle_scene.api")

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

func die() -> void:
	if battle_scene and battle_scene.api:
		battle_scene.api.resolve_death(combat_id, "legacy_die")
		return
	# (optional) emergency fallback if called outside battle
	combatant_data.alive = false

func fade():
	for child in get_children():
		if child is FighterBehavior:
			child._on_fade()
	

func do_turn() -> void:
	print("fighter.gd do_turn() name: ", name)
	for child in get_children():
		if child is FighterBehavior:
			child._on_do_turn()

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
	return status_system._has_status(status_id)

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

func _on_data_changed() -> void:
	if battle_scene and battle_scene.api:
		# cast if you want, or just call a method on BattleAPI base
		battle_scene.api.observe_stats_changed(self)

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

func _is_attack_targeting_us(ctx: AttackTargetContext) -> bool:
	# Source and self must be on opposite sides.
	return ctx.source.get_parent() != get_parent()

func get_combat_id() -> int:
	return state.combat_id

func get_data() -> CombatantData:
	return state.data
