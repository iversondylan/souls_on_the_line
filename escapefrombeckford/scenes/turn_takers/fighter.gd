class_name Fighter extends TurnTaker

#enum RetargetPriority {NONE, FRONT}

#@export var combatant_data: CombatantData : set = _set_combatant_data
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
var combatant_data: CombatantData : set = _set_combatant_data
var battle_scene: BattleScene# : set = _set_battle_scene
#STATUSES IS A PLACEHOLDER SYSTEM CURRENTLY
#STATUSES SHOULD BE TRACKED DIFFERENTLY
var statuses: Array[String] = []

var fighter_tween: Tween
var anchor_position: Vector2 = Vector2(0, 0)

func _ready() -> void:
	combatant.target_area_area_entered.connect(_on_target_area_area_entered)
	combatant.target_area_area_exited.connect(_on_target_area_area_exited)
	target_area.combatant = self

#func _set_battle_scene(_battle_scene: BattleScene) -> void:
	#battle_scene = _battle_scene

func enter() -> void:
	do_turn()

func _set_combatant_data(new_data: CombatantData) -> void:
	combatant_data = new_data
	#combatant_data.fighter = self
	name = combatant_data.name
	combatant.combatant_data = combatant_data

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
	damage_effect.n_damage = n_damage
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
					turn_complete()
					combatant.health_bar.show() )
	else:
		tween.finished.connect( func(): 
			attack(targets, n_damage, n_attacks, retarget, explode)
			)

#func make_tween() -> Tween:
	#if fighter_tween and fighter_tween.is_valid():
		#fighter_tween.kill()
	#fighter_tween = create_tween()
	#return fighter_tween

#func get_tween() -> Tween:
	#if fighter_tween and fighter_tween.is_valid():
		#return fighter_tween
	#fighter_tween = create_tween()
	#return fighter_tween

func add_status(status: String) -> void:
	statuses.push_back(status)
	var focus_status_icon_resource : IconData = load("res://icon_data/focus_status_icon.tres")
	var status_icon: IconData = focus_status_icon_resource.duplicate()
	
	var status_icons: Array[IconData]
	status_icons.push_back(status_icon)
	status_bar.display_icons_from_data(status_icons)

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
	#if card_with_id:
		#Events.summon_reserve_card_released.emit(self)
	var death_tween: Tween = create_tween()
	death_tween.tween_property(character_sprite, "modulate", Color.BLACK, 0.3)
	death_tween.finished.connect(
		func():
			battle_group.combatant_died(self)
				)

func do_turn() -> void:
	#doing_turn = true
	combatant_data.set_armor(0)
	combatant_data.reset_mana()
	#Events.turn_taker_turn_completed.emit(self)
	#if !current_action:
		#doing_turn = false
		#turn_complete = true
		#Events.npc_action_completed.emit(battle_group)
		#return
	#current_action.perform_action()
	#intent_container.clear_display()

func reset():
	combatant_data.health = combatant_data.max_health
	#combatant_data.mana_red = combatant_data.max_mana_red
	#combatant_data.mana_green = combatant_data.max_mana_green
	#combatant_data.mana_blue = combatant_data.max_mana_blue
	combatant_data.armor = combatant_data.starting_armor
	combatant_data.stats_changed()

func _on_target_area_area_entered(area: Area2D) -> void:
	#Events.combatant_touched.emit(self)
	#targeted_arrow.show()
	pass

func _on_target_area_area_exited(area: Area2D) -> void:
	pass

func get_mean_position(targets: Array[Fighter]) -> Vector2:
	var cum_target_position := Vector2.ZERO
	var n_targets: float = float(targets.size())
	for target: Fighter in targets:
		cum_target_position += target.global_position
	return cum_target_position/n_targets #average global position of targets
