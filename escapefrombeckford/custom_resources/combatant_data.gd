class_name CombatantData extends Resource

signal combatant_data_changed()

@export_group("Visuals")
@export var name: String = "error"
@export_multiline var description: String
@export var character_art: Texture2D
@export var portrait: Texture2D
@export var character_scale: float = 1
@export var facing_right: bool = true
@export var height: int = 365

@export_group("Gameplay Data")
@export var max_health: int = 10
@export var max_mana_red: int = 3
@export var max_mana_green: int = 3
@export var max_mana_blue: int = 3
@export var starting_armor: int = 0
@export var team: int = 1
@export var ai: PackedScene

@export_group("Audio")
@export var attack_sound: AudioStream = load("res://assets/sfx/thrall_hit.wav")

var fighter: Fighter
var is_alive: bool = true
var health: int : set = set_health
var armor: int : set = set_armor
var mana_red: int : set = set_mana_red
var mana_green: int : set = set_mana_green
var mana_blue: int : set = set_mana_blue
var rank: int

func stats_changed() -> void:
	if fighter is Player:
		Events.player_combatant_data_changed.emit()
	combatant_data_changed.emit()

func set_health(value : int) -> void:
	health = clampi(value, 0, max_health)
	stats_changed()

func set_armor(value : int) -> void:
	armor = clampi(value, 0, 999)
	stats_changed()
	
func add_armor(value: int) -> void:
	armor = clampi(armor + value, 0, 999)
	stats_changed()

func take_damage(damage: int) -> int:
	var health_loss: int = 0
	if damage <= armor:
		armor = armor - damage
	else:
		health_loss = damage - armor
		health -= health_loss
		armor = 0
	stats_changed()
	return health_loss

func check_lethal(damage: int) -> bool:
	var health_loss: int = 0
	if damage <= armor:
		return false
	else:
		health_loss = damage - armor
		if health_loss >= health:
			return true
		else:
			return false

func take_health_damage(damage : int) -> void:
	health -= damage
	stats_changed()

func heal(amount : int) -> void:
	health = clampi(health + amount, 0, max_health)
	stats_changed()

func create_instance() -> CombatantData:
	var instance: CombatantData = duplicate()
	instance.health = max_health
	instance.armor = 0
	instance.reset_mana()
	stats_changed()
	return instance
	

func spend_mana(card_data: CardData) -> bool:
	if mana_red >= card_data.cost_red and mana_green >= card_data.cost_green and mana_blue >= card_data.cost_blue:
		mana_red -= card_data.cost_red
		mana_green -= card_data.cost_green
		mana_blue -= card_data.cost_blue
		stats_changed()
		return true
	else:
		return false
	

func set_mana_red(value: int) -> void:
	mana_red = value
	stats_changed()

func set_mana_green(value: int) -> void:
	mana_green = value
	stats_changed()

func set_mana_blue(value: int) -> void:
	mana_blue = value
	stats_changed()

func reset_mana() -> void:
	mana_red = max_mana_red
	mana_green = max_mana_green
	mana_blue = max_mana_blue
	stats_changed()

func can_play_card(card_data: CardData) -> bool:
	return mana_red >= card_data.cost_red and mana_green >= card_data.cost_green and mana_blue >= card_data.cost_blue
#func on_player_turn_started():
	#pass
#
#func on_player_turn_ended():
	#pass
#
#func on_enemy_turn_started():
	#pass
#
#func on_enemy_turn_ended():
	#pass
