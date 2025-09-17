class_name Combatant extends Node2D

signal target_area_area_entered(area: Area2D)
signal target_area_area_exited(area: Area2D)

@onready var character_sprite: Sprite2D = $CharacterArt
@onready var target_area: CombatantTargetArea = $TargetArea
@onready var targeted_arrow: Sprite2D = $TargetedArrow
@onready var health_bar: HealthBar = $HealthBar

@onready var armor_sprite: Sprite2D = $Armor
@onready var armor_label: Label = $Armor/Label
@onready var status_bar: IconViewPanel = %StatusBar
@onready var intent_container: IconViewPanel = $IconViewPanel
@onready var area_left: CombatantAreaLeft = $AreaLeft

var combatant_data: CombatantData : set = _set_combatant_data

func _set_combatant_data(new_data: CombatantData) -> void:
	combatant_data = new_data
	name = combatant_data.name
	#load_ai()
	if not combatant_data.combatant_data_changed.is_connected(update_data_visuals):
		combatant_data.combatant_data_changed.connect(update_data_visuals)
	#if not combatant_data.combatant_data_changed.is_connected(update_action):
		#combatant_data.combatant_data_changed.connect(update_action)
	load_combatant_data()
	#update_data_visuals()

func load_combatant_data():
	if !is_node_ready():
		await ready
	character_sprite.texture = combatant_data.character_art #.set_texture(combatant_data.character_art)
	var scalar: float = float(combatant_data.height) / character_sprite.texture.get_height()
	character_sprite.scale = Vector2(scalar, scalar)
	character_sprite.position = Vector2(0, - combatant_data.height / 2.0)
	intent_container.position = Vector2(0, - combatant_data.height + 20)
	targeted_arrow.position = Vector2(0, - combatant_data.height)
	health_bar.init_health(combatant_data.max_health)
	health_bar.n_health = combatant_data.health

func update_data_visuals() -> void:
	if !is_node_ready():
		await ready
	update_health_bar()
	update_armor_icon()

func update_health_bar():
	#health_bar.init_health(combatant_data.max_health)
	if health_bar.max_value != combatant_data.max_health:
		health_bar.max_value = combatant_data.max_health
	if health_bar.damage_bar.max_value != combatant_data.max_health:
		health_bar.damage_bar.max_value = combatant_data.max_health
	if health_bar.value != combatant_data.health:
		health_bar.n_health = combatant_data.health

func update_armor_icon():
	if combatant_data.armor > 0:
		armor_sprite.visible = true
		armor_label.set_text(str(combatant_data.armor))
		armor_label.visible = true
	else:
		armor_sprite.visible = false
		armor_label.visible = false

func _on_target_area_area_entered(area: Area2D) -> void:
	target_area_area_entered.emit(area)


func _on_target_area_area_exited(area: Area2D) -> void:
	target_area_area_exited.emit(area)
