# combatant_data.gd

class_name CombatantData extends Resource

signal combatant_data_changed()

@export_group("Visuals")
@export var name: String = "error"
@export_multiline var description: String
@export var character_art: Texture2D
@export var character_art_uid: String
@export var portrait: Texture2D
@export var portrait_art_uid: String
#@export var character_scale: float = 1
@export var facing_right: bool = true
@export var height: int = 365
@export var color_tint: Color = Color.WHITE

@export_group("Gameplay Data")
@export var max_health: int = 10
@export var apr: int = 3
@export var apm: int = 3
@export var max_mana: int = 3
#@export var behaviors: Array[FighterBehavior]
@export var ai: NPCAIProfile

@export_group("Audio")
var alive: bool = true
var health: int = -1# : set = set_health
var armor: int# : set = set_armor
var mana: int# : set = set_mana
var combat_id: int
#var rank: int

func init():
	if health < 0:
		health = max_health

func is_alive() -> bool:
	return health > 0 and alive

func stats_changed() -> void:
	# This check is smelly. 
	# Should not emit global events or do class checks here
	if self is PlayerData:
		Events.player_combatant_data_changed.emit()
	combatant_data_changed.emit()

func apply_damage(ctx: DamageContext) -> void:
	# Only numeric work here. No Fighter references required.
	var health_loss := take_damage(ctx.final_amount)
	ctx.health_loss = health_loss
	ctx.blocked = (health_loss <= 0)
	ctx.lethal = (health <= 0 or !alive)

func apply_damage_amount(amount: int) -> Dictionary:
	# returns { "armor_damage": int, "health_damage": int, "was_lethal": bool }
	var pre_armor := armor
	var health_loss := take_damage(amount)
	var armor_damage := maxi(mini(amount, pre_armor), 0)
	var was_lethal := (health <= 0) or (not alive)
	return {
		"armor_damage": armor_damage,
		"health_damage": health_loss,
		"was_lethal": was_lethal,
	}

func set_health(value : int) -> void:
	health = clampi(value, 0, max_health)
	stats_changed()

func reset_health() -> void:
	health = max_health
	stats_changed()

func reset_armor() -> void:
	set_armor(0)

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
		health = clampi(health - health_loss, 0, max_health)
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
	health = clampi(health - damage, 0, max_health)
	stats_changed()

func heal(ctx : HealContext) -> int:
	if ctx.flat_amount < 0 or ctx.of_total < 0.0 or ctx.of_missing < 0.0:
		push_warning("combatant_data.gd heal() negative heal????")
		return 0
	var initial_health := health
	health = clampi(health + ctx.flat_amount, 0, max_health)
	health = clampi(health + floori(health*ctx.of_total), 0, max_health)
	health = clampi(health + floori((max_health-health)*ctx.of_missing), 0, max_health)
	stats_changed()
	return health - initial_health

func increase_max_health(amount: int, heal_same := true) -> void:
	max_health += amount
	if heal_same:
		health = clampi(health + amount, 0, max_health)
	stats_changed()

func create_instance() -> CombatantData:
	var instance: CombatantData = duplicate()
	instance.health = max_health
	instance.armor = 0
	instance.reset_mana()
	instance.stats_changed()
	return instance

func can_play_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var cost := card_data.cost
	return mana >= cost

func spend_mana(card_data: CardData) -> bool:
	if !can_play_card(card_data):
		return false
	mana = maxi(mana - card_data.get_total_cost(), 0)
	stats_changed()
	return true

func add_mana(n: int) -> void:
	mana += n
	stats_changed()

func reset_mana() -> void:
	mana = max_mana
	stats_changed()
