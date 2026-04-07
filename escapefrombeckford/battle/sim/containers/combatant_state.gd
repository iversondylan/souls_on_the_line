# combatant_state.gd

class_name CombatantState extends RefCounted

enum Mortality { MORTAL, SOULBOUND, DEPLETE }

static func get_mortality_cap(mortality: int) -> int:
	match int(mortality):
		int(Mortality.SOULBOUND):
			return 3
		int(Mortality.DEPLETE):
			return 2
		_:
			return 0

var id: int
var combatant_data: CombatantData
var team: int  # 0 friendly, 1 enemy
var alive: bool = true
var type: CombatantView.Type
var mortality: Mortality
# Stats (data-only)
var name: String = ""
var max_health: int = 0
var health: int = 0
var armor: int = 0

# mana + attack powers
var max_mana: int = 0
var mana: int = 0
var apm: int = 0 # attack power melee
var apr: int = 0 # attack power ranged

var bound_card_uid: String = ""

# Authoring refs
var data_proto_path: String = "" # optional for reconstruction

# Systems (data-side) - keep stubs, even if you ignore them for now
var statuses: StatusState = StatusState.new()
var modifiers: ModifierCache = ModifierCache.new()

# AI (data-side)
var ai_profile: NPCAIProfile
var ai_state: Dictionary = {}

# RNG stream (deterministic per unit)
var rng: RNG

func init_unit_rng(rng_seed: int) -> void:
	rng = RNG.new()
	rng.rng_seed = rng_seed

func is_alive() -> bool:
	return alive and health > 0

func init_from_combatant_data(data: CombatantData, current_health_override: int = -1) -> void:
	if !data:
		return
	combatant_data = data
	name = data.name
	max_health = int(data.max_health)
	health = clampi(int(current_health_override if current_health_override >= 0 else data.max_health), 0, max_health)
	armor = 0
	ai_profile = data.ai
	max_mana = maxi(int(data.max_mana), 0)
	mana = max_mana

	apm = maxi(int(data.apm), 0)
	apr = maxi(int(data.apr), 0)

	alive = max_health > 0

func clone() -> CombatantState:
	var c := CombatantState.new()
	c.id = id
	c.combatant_data = combatant_data
	c.team = team
	c.alive = alive
	c.type = type
	c.mortality = mortality

	c.name = name
	c.max_health = max_health
	c.health = health
	c.armor = armor

	c.max_mana = max_mana
	c.mana = mana
	c.apm = apm
	c.apr = apr
	c.bound_card_uid = bound_card_uid

	c.data_proto_path = data_proto_path

	c.statuses = statuses.clone()
	c.modifiers = modifiers.clone()
	c.ai_profile = ai_profile
	c.ai_state = ai_state.duplicate(true)

	if rng:
		c.rng = RNG.new()
		c.rng.rng_seed = rng.rng_seed

	return c

func increase_max_health(amount: int, heal_added_health: bool = true) -> void:
	if amount <= 0:
		return

	max_health += amount
	if heal_added_health:
		health = clampi(health + amount, 0, max_health)
	else:
		health = clampi(health, 0, max_health)
