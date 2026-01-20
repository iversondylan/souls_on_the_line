# combatant.gd
class_name Combatant extends Node2D

signal target_area_area_entered(area: Area2D)
signal target_area_area_exited(area: Area2D)
signal statuses_applied(proc_type: Status.ProcType)

@onready var character_sprite: Sprite2D = $CharacterArt
@onready var target_area: CombatantTargetArea = $TargetArea
@onready var targeted_arrow: Sprite2D = $TargetedArrow
@onready var pending_turn_glow: Sprite2D = $PendingTurnGlow

@onready var health_bar: HealthBar = $HealthBar
@onready var armor_sprite: Sprite2D = $Armor
@onready var armor_label: Label = $Armor/Label
#@onready var status_bar: IconViewPanel = %StatusBar
@onready var intent_container: IntentContainer = $IntentContainer
@onready var area_left: CombatantAreaLeft = $AreaLeft
@onready var status_grid: StatusGrid = $StatusGrid

var combatant_data: CombatantData : set = _set_combatant_data
var fighter: Fighter : set = _set_fighter
var battle_scene: BattleScene : set = _set_battle_scene

func _ready() -> void:
	status_grid.statuses_applied.connect(_on_status_grid_statuses_applied)
	
	if not target_area.input_event.is_connected(_on_target_area_input_event):
		target_area.input_event.connect(_on_target_area_input_event)
	
	if not target_area.mouse_entered.is_connected(_on_target_area_mouse_entered):
		target_area.mouse_entered.connect(_on_target_area_mouse_entered)
	
	if not target_area.mouse_exited.is_connected(_on_target_area_mouse_exited):
		target_area.mouse_exited.connect(_on_target_area_mouse_exited)

func _set_combatant_data(new_data: CombatantData) -> void:
	combatant_data = new_data
	name = combatant_data.name
	if not combatant_data.combatant_data_changed.is_connected(update_data_visuals):
		combatant_data.combatant_data_changed.connect(update_data_visuals)
	load_combatant_data()

func _set_fighter(new_fighter: Fighter) -> void:
	fighter = new_fighter
	if !is_node_ready():
		await ready
	status_grid.status_parent = fighter

func _set_battle_scene(new_battle_scene: BattleScene) -> void:
	battle_scene = new_battle_scene
	if !is_node_ready():
		await ready
	status_grid.battle_scene = battle_scene

func load_combatant_data():
	if !is_node_ready():
		await ready
	character_sprite.texture = combatant_data.character_art #.set_texture(combatant_data.character_art)
	character_sprite.modulate = combatant_data.color_tint
	var scalar: float = float(combatant_data.height) / character_sprite.texture.get_height()
	character_sprite.scale = Vector2(scalar, scalar)
	character_sprite.position = Vector2(0, - combatant_data.height / 2.0)
	intent_container.position = Vector2(0, - combatant_data.height + 20)
	targeted_arrow.position = Vector2(0, - combatant_data.height)
	health_bar.update_health(combatant_data)

func info_visible(visibility: bool) -> void:
	intent_container.visible = visibility
	#status_bar.visible = visibility
	health_bar.visible = visibility
	status_grid.visible = visibility
	
	

func update_data_visuals() -> void:
	if !is_node_ready():
		await ready
	update_health_bar()
	update_armor_icon()

func update_health_bar():
	health_bar.update_health(combatant_data)

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

func _on_status_grid_statuses_applied(proc_type: Status.ProcType):
	statuses_applied.emit(proc_type)


func _on_target_area_mouse_entered() -> void:
	if fighter and fighter.is_alive():
		Events.combatant_target_hovered.emit(fighter)


func _on_target_area_mouse_exited() -> void:
	if fighter and fighter.is_alive():
		Events.combatant_target_unhovered.emit(fighter)


func _on_target_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		if fighter and fighter.is_alive():
			Events.combatant_target_clicked.emit(fighter)
			get_viewport().set_input_as_handled()
