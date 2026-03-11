# combatant_state.gd

class_name CombatantState extends RefCounted

var id: int
var combatant_data: CombatantData
var team: int  # 0 friendly, 1 enemy
var alive: bool = true
var type: CombatantView.Type
var mortality: CombatantView.Mortality
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

# the status_dict is newer and possibly replacing StatusState.
# id:StringName -> {duration:int, intensity:int}
#var status_dict: Dictionary = {} # &"amplify" -> {"duration":2,"intensity":1}

# RNG stream (deterministic per unit)
var rng: RNG

func init_unit_rng(seed: int) -> void:
	rng = RNG.new()
	rng.seed = seed

func is_alive() -> bool:
	return alive and health > 0

func init_from_combatant_data(data: CombatantData) -> void:
	if !data:
		return
	combatant_data = data
	name = data.name
	max_health = int(data.max_health)
	health = clampi(int(data.health if data.health >= 0 else data.max_health), 0, max_health)
	armor = int(data.armor)
	ai_profile = data.ai
	max_mana = maxi(int(data.max_mana), 0)
	mana = clampi(int(data.mana), 0, max_mana)

	apm = maxi(int(data.apm), 0)
	apr = maxi(int(data.apr), 0)

	alive = data.is_alive()

func clone() -> CombatantState:
	var c := CombatantState.new()
	c.id = id
	c.team = team
	c.alive = alive

	c.name = name
	c.max_health = max_health
	c.health = health
	c.armor = armor

	c.max_mana = max_mana
	c.mana = mana
	c.apm = apm
	c.apr = apr

	c.data_proto_path = data_proto_path

	c.statuses = statuses.clone()
	c.modifiers = modifiers.clone()
	c.ai_state = ai_state.duplicate(true)

	if rng:
		c.rng = RNG.new()
		c.rng.seed = rng.seed

	return c
