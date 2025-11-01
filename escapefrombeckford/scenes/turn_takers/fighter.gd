class_name Fighter extends Node2D

signal turn_taker_turn_complete(turn_taker: Fighter)
@export var battle_group: BattleGroup
@onready var combatant: Combatant = $Combatant
@onready var character_sprite: Sprite2D = combatant.character_sprite
@onready var target_area: CombatantTargetArea = combatant.target_area
@onready var targeted_arrow: Sprite2D = combatant.targeted_arrow
@onready var health_bar: HealthBar = combatant.health_bar
@onready var armor_sprite: Sprite2D = combatant.armor_sprite
@onready var armor_label: Label = combatant.armor_label
@onready var status_bar: IconViewPanel = combatant.status_bar
@onready var intent_container: IconViewPanel = combatant.intent_container
@onready var area_left: CombatantAreaLeft = combatant.area_left
@onready var damage_number_scn: PackedScene = preload("res://scenes/ui/damage_number.tscn")
@onready var blocked_message_scn: PackedScene = preload("res://scenes/ui/blocked_message.tscn")
@onready var modifier_system: ModifierSystem = $ModifierSystem

var combatant_data: CombatantData : set = _set_combatant_data
var battle_scene: BattleScene : set = _set_battle_scene
#STATUSES IS A PLACEHOLDER SYSTEM CURRENTLY
#STATUSES SHOULD BE TRACKED DIFFERENTLY
var statuses: Array[String] = []

var fighter_tween: Tween
var anchor_position: Vector2 = Vector2(0, 0)

func _ready() -> void:
	combatant.target_area_area_entered.connect(_on_target_area_area_entered)
	combatant.target_area_area_exited.connect(_on_target_area_area_exited)
	Events.aura_changed.connect(on_aura_changed)
	Events.aura_removed.connect(_on_aura_removed)
	target_area.combatant = self
	combatant.fighter = self

func _set_combatant_data(new_data: CombatantData) -> void:
	combatant_data = new_data
	name = combatant_data.name
	combatant.combatant_data = combatant_data
	
	for child in get_children():
		if child.has_method("_on_combatant_data_set"):
			child._on_combatant_data_set(new_data)
	reset()

func _set_battle_scene(new_battle_scene: BattleScene) -> void:
	battle_scene = new_battle_scene
	if !is_node_ready():
		await ready
	combatant.battle_scene = battle_scene

func enter() -> void:
	combatant.status_grid.apply_statuses_by_type(Status.ProcType.START_OF_TURN)
	for child in get_children():
		if child.has_method("_on_enter"):
			child._on_enter()

func exit() -> void:
	combatant.status_grid.apply_statuses_by_type(Status.ProcType.END_OF_TURN)
	for child in get_children():
		if child.has_method("_on_exit"):
			child._on_exit()

func attack(targets: Array[Fighter], n_damage: int, n_attacks: int = 1, retarget: AttackEffect.RetargetPriority = AttackEffect.RetargetPriority.FRONT, explode: bool = false):
	combatant.health_bar.hide()
	var retargeting: bool = false
	if targets.size() == 1 and retarget == AttackEffect.RetargetPriority.FRONT:
		if !targets[0] or !targets[0].combatant_data.is_alive:
			var target_battle_group_index: int
			if get_parent() is BattleGroupEnemy:
				target_battle_group_index = 0
			else:
				target_battle_group_index = 1
			retargeting = true
			targets = [battle_scene.get_front_combatant(target_battle_group_index)]
	var start := global_position
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT)
	var end: Vector2
	end = get_mean_position(targets)
	tween.tween_property(self, "global_position", end, 0.4)
	var damage_effect := DamageEffect.new()
	
	damage_effect.n_damage = modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	modifier_system.get_modified_value(n_damage, Modifier.Type.DMG_DEALT)
	
	damage_effect.sound = combatant_data.attack_sound
	tween.tween_callback(damage_effect.execute.bind(targets))
	tween.tween_interval(0.5)
	n_attacks -= 1
	if n_attacks <= 0:
		if explode:
			tween.finished.connect( func(): die() )
		else:
			tween.tween_property(self, "position", anchor_position, 0.4)
			tween.finished.connect( 
				func(): 
					if battle_group.acting_fighters[0] == self:
						turn_complete()
					combatant.health_bar.show() )
	else:
		tween.finished.connect( func(): 
			attack(targets, n_damage, n_attacks, retarget, explode)
			)

#func add_status(status: String) -> void:
	#statuses.push_back(status)
	#var focus_status_icon_resource : IconData = load("res://icon_data/focus_status_icon.tres")
	#var status_icon: IconData = focus_status_icon_resource.duplicate()
	#
	#var status_icons: Array[IconData]
	#status_icons.push_back(status_icon)
	#status_bar.display_icons_from_data(status_icons)

#func spawned() -> void:
	#for child in get_children():
		#if child.has_method("_on_spawned"):
			#child._on_spawned()

func set_anchor_position(_position: Vector2, animate: bool) -> void:
	anchor_position = _position
	if animate:
		var tween = create_tween()
		tween.tween_property(self, "anchor_position", _position, 0.4)
	else:
		position = anchor_position

func take_damage(n_damage: int):
	if combatant_data.check_lethal(n_damage):
		combatant_data.is_alive = false
		battle_group.update_combatant_position()
	var tween: Tween = create_tween()
	tween.tween_callback(Shaker.shake.bind(self, 16, 0.15))
	tween.tween_interval(0.2)
	tween.finished.connect(take_damage_part_2.bind(n_damage))

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

func add_armor(amount: int):
	combatant_data.add_armor(amount)

func die():
	combatant_data.is_alive = false
	battle_group.update_combatant_position()
	var death_tween: Tween = create_tween()
	death_tween.tween_property(character_sprite, "modulate", Color.BLACK, 0.3)
	death_tween.finished.connect(
		func():
			battle_group.combatant_died(self)
				)
	for child in get_children():
		if child.has_method("_on_die"):
			child._on_die()

func do_turn() -> void:
	combatant_data.set_armor(0)
	combatant_data.reset_mana()
	for child in get_children():
		if child.has_method("_on_do_turn"):
			child._on_do_turn()

func update_action() -> void:
	for child in get_children():
		if child.has_method("update_action"):
			child.update_action()
#func reset():
	#combatant_data.health = combatant_data.max_health
	#combatant_data.armor = combatant_data.starting_armor
	#combatant_data.stats_changed()

#func bind_card(new_card_data: CardData) -> void:
	#for child in get_children():
		#if child.has_method("_on_bind_card"):
			#child._on_bind_card(new_card_data)

func traverse_player() -> void:
	for child in get_children():
		if child.has_method("_on_traverse_player"):
			child._on_traverse_player()

func can_play_card(card_data: CardData) -> bool:
	return combatant_data.can_play_card(card_data)
#enum TargetType {
	#SELF,
	#BATTLEFIELD,
	#ALLY_OR_SELF,
	#ALLY,
	#SINGLE_ENEMY,
	#ALL_ENEMIES,
	#EVERYONE
#}

func spend_mana(card_data: CardData) -> bool:
	if combatant_data.spend_mana(card_data):
		return true
	else:
		return false

func discard_summon_reserve_card(_deck: Deck) -> void:
	for child in get_children():
		if child.has_method("_on_discard_summon_reserve_card"):
			child._on_discard_summon_reserve_card(_deck)

func reset():
	combatant_data.health = combatant_data.max_health
	combatant_data.mana_red = combatant_data.max_mana_red
	combatant_data.mana_green = combatant_data.max_mana_green
	combatant_data.mana_blue = combatant_data.max_mana_blue
	combatant_data.armor = combatant_data.starting_armor
	combatant_data.stats_changed()
	Events.auras_requested.emit(self)

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

func _on_target_area_area_exited(area: Area2D) -> void:
	hide_targeted_arrow()

func on_aura_changed(source_fighter: Fighter, aura_primary: AuraPrimary) -> void:
	if aura_primary.aura_type == AuraPrimary.AuraType.ALLIES:
		if battle_group == source_fighter.battle_group and self != source_fighter:
			add_aura_secondary(source_fighter, aura_primary)
	elif battle_group != source_fighter.battle_group:
		add_aura_secondary(source_fighter, aura_primary)

## THIS NEEDS TO BE CHANGED TO TRACK DUPLICATE AURAS AND SOURCES
func add_aura_secondary(source_fighter: Fighter, aura_primary: AuraPrimary) -> void:
	#print("fighter.gd add_aura_secondary() applying aura secondary: %s" % aura_status.id)
	var aura_secondary := aura_primary.aura_secondary.duplicate()
	aura_secondary.source = source_fighter
	aura_secondary.intensity = aura_primary.intensity
	aura_secondary.status_parent = self
	print("fighter.gd adding aura secondary. source: %s, intensity: %s, target: %s" % [aura_secondary.source, aura_secondary.intensity, aura_secondary.status_parent])
	combatant.status_grid.add_status(aura_secondary)

func _on_aura_removed(source_fighter: Fighter, aura_status: Status) -> void:
	pass

func show_targeted_arrow() -> void:
	targeted_arrow.show()

func hide_targeted_arrow() -> void:
	targeted_arrow.hide()

func get_mean_position(targets: Array[Fighter]) -> Vector2:
	var cum_target_position := Vector2.ZERO
	var n_targets: float = float(targets.size())
	for target: Fighter in targets:
		cum_target_position += target.global_position
	return cum_target_position/n_targets #average global position of targets

func turn_complete() -> void:
	#print("turn_taker.gd turn_complete(): %s" % name)
	turn_taker_turn_complete.emit(self)
