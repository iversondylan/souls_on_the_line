# combatant_data.gd

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
@export var color_tint: Color = Color.WHITE

@export_group("Gameplay Data")
@export var max_health: int = 10
@export var max_mana_red: int = 3
@export var max_mana_green: int = 3
@export var max_mana_blue: int = 3
@export var ai: NPCAIProfile

@export_group("Audio")
var alive: bool = true
var health: int = -1# : set = set_health
var armor: int# : set = set_armor
var mana_red: int# : set = set_mana_red
var mana_green: int# : set = set_mana_green
var mana_blue: int# : set = set_mana_blue
var rank: int

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

# TODO: implement this
func apply_damage(ctx: DamageContext) -> void:
	# Only numeric work here. No Fighter references required.
	var health_loss := take_damage(ctx.final_amount)
	ctx.health_loss = health_loss
	ctx.blocked = (health_loss <= 0)
	ctx.lethal = (health <= 0 or !alive)


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
	

func spend_mana(card_data: CardData) -> bool:
	if !can_play_card(card_data):
		return false

	var remaining := card_data.cost_red + card_data.cost_green + card_data.cost_blue
	if remaining <= 0:
		return true

	# Normal RR cursor always starts at red.
	var cursor := 0 # 0=R, 1=G, 2=B

	while remaining > 0:
		# ------------------------------------------------------------
		# 1) REPAIR STEP (fix "unexpectedly high" / broken ordering)
		# Maintain R <= G <= B by spending from the pool that's too high.
		# IMPORTANT: repair does NOT advance cursor; RR resumes at red.
		# ------------------------------------------------------------
		if (mana_red > mana_green or mana_red > mana_blue) and mana_red > 0:
			mana_red -= 1
			remaining -= 1
			cursor = 0
			continue

		if (mana_green > mana_blue) and mana_green > 0:
			mana_green -= 1
			remaining -= 1
			cursor = 0
			continue

		# ------------------------------------------------------------
		# 2) NORMAL ROUND ROBIN (R -> G -> B), but only if the spend
		# would keep R <= G <= B. Skip invalid/empty options.
		# ------------------------------------------------------------
		var spent := false

		for i in range(3):
			var idx := (cursor + i) % 3

			match idx:
				0:
					# Spending red always preserves R <= G and R <= B.
					if mana_red > 0:
						mana_red -= 1
						spent = true
				1:
					# Can only spend green if it stays >= red after spend.
					if mana_green > 0 and (mana_green - 1) >= mana_red:
						mana_green -= 1
						spent = true
				2:
					# Can only spend blue if it stays >= green after spend.
					if mana_blue > 0 and (mana_blue - 1) >= mana_green:
						mana_blue -= 1
						spent = true

			if spent:
				cursor = (idx + 1) % 3
				remaining -= 1
				break

		# Should be unreachable if total mana >= total cost, but keep safety.
		if !spent:
			push_error("spend_mana(): unable to spend while can_play_card() was true (ordering constraint deadlock)")
			return false

	stats_changed()
	return true


func add_mana(n_red: int, n_green: int, n_blue: int) -> void:
	mana_red += n_red
	mana_green += n_green
	mana_blue += n_blue
	stats_changed()

func reset_mana() -> void:
	mana_red = max_mana_red
	mana_green = max_mana_green
	mana_blue = max_mana_blue
	stats_changed()

func can_play_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var total_cost := card_data.cost_red + card_data.cost_green + card_data.cost_blue
	var total_mana := mana_red + mana_green + mana_blue
	return total_mana >= total_cost
