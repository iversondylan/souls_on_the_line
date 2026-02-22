# combatant_resolver.gd
class_name CombatantResolver extends RefCounted

# --------------------------------------------
# Core queries
# --------------------------------------------

static func is_alive(u: CombatantState) -> bool:
	return u != null and u.alive and u.health > 0


# --------------------------------------------
# Armor
# --------------------------------------------

static func set_armor(u: CombatantState, value: int) -> void:
	if !u:
		return
	u.armor = clampi(int(value), 0, 999)

static func add_armor(u: CombatantState, delta: int) -> void:
	if !u:
		return
	set_armor(u, u.armor + int(delta))

static func reset_armor(u: CombatantState) -> void:
	if !u:
		return
	u.armor = 0


# --------------------------------------------
# Mana
# --------------------------------------------

static func set_max_mana(u: CombatantState, value: int, clamp_current := true) -> void:
	if !u:
		return
	u.max_mana = maxi(int(value), 0)
	if clamp_current:
		u.mana = clampi(u.mana, 0, u.max_mana)

static func set_mana(u: CombatantState, value: int) -> void:
	if !u:
		return
	u.mana = clampi(int(value), 0, maxi(u.max_mana, 0))

static func add_mana(u: CombatantState, delta: int) -> void:
	if !u:
		return
	set_mana(u, u.mana + int(delta))

static func reset_mana(u: CombatantState) -> void:
	if !u:
		return
	u.mana = maxi(u.max_mana, 0)

static func can_spend_mana(u: CombatantState, cost: int) -> bool:
	if !u:
		return false
	cost = maxi(int(cost), 0)
	return u.mana >= cost

static func spend_mana(u: CombatantState, cost: int) -> bool:
	# Returns true if cost paid; false if insufficient.
	if !u:
		return false
	cost = maxi(int(cost), 0)
	if cost <= 0:
		return true
	if u.mana < cost:
		return false
	u.mana -= cost
	return true


# --------------------------------------------
# Damage / Death
# --------------------------------------------

# Returns a small result dictionary so callers can emit events later.
# { "armor_damage": int, "health_damage": int, "was_lethal": bool }
static func apply_damage_amount(u: CombatantState, amount: int) -> Dictionary:
	var out := {
		"armor_damage": 0,
		"health_damage": 0,
		"was_lethal": false,
	}

	if !u:
		return out
	if !is_alive(u):
		return out

	amount = maxi(int(amount), 0)
	if amount <= 0:
		return out

	var pre_armor := int(u.armor)

	# Eat armor first
	if amount <= u.armor:
		u.armor -= amount
		out.armor_damage = amount
		out.health_damage = 0
	else:
		var remaining := amount - u.armor
		out.armor_damage = pre_armor
		u.armor = 0

		var pre_health := int(u.health)
		u.health = clampi(u.health - remaining, 0, maxi(u.max_health, 0))
		out.health_damage = pre_health - u.health

	# Lethal check
	out.was_lethal = (u.health <= 0) or (not u.alive)
	if out.was_lethal:
		# Convention: mark dead immediately at the data level.
		# Structural removal (from group/order) should be a different system.
		die(u, "damage")

	return out

static func check_lethal(u: CombatantState, amount: int) -> bool:
	if !u:
		return false
	if !is_alive(u):
		return true
	amount = maxi(int(amount), 0)
	if amount <= 0:
		return false
	return amount > u.armor and (amount - u.armor) >= u.health

static func die(u: CombatantState, _reason: String = "") -> void:
	if !u:
		return
	u.alive = false
	u.health = 0
	# Note: don’t remove from group.order here — that’s a Battle/Group resolver concern.


# --------------------------------------------
# Healing (optional but fits “combatant_data-ish”)
# --------------------------------------------

static func heal_flat(u: CombatantState, amount: int) -> int:
	if !u:
		return 0
	if !is_alive(u):
		return 0
	amount = maxi(int(amount), 0)
	if amount <= 0:
		return 0

	var pre := int(u.health)
	u.health = clampi(u.health + amount, 0, maxi(u.max_health, 0))
	return u.health - pre

static func set_health(u: CombatantState, value: int) -> void:
	if !u:
		return
	u.health = clampi(int(value), 0, maxi(u.max_health, 0))
	if u.health <= 0:
		u.alive = false

static func reset_health(u: CombatantState) -> void:
	if !u:
		return
	u.health = maxi(u.max_health, 0)
	u.alive = true


# --------------------------------------------
# Attack power (apm/apr) helpers
# --------------------------------------------

static func set_attack_power_melee(u: CombatantState, value: int) -> void:
	if !u:
		return
	u.apm = maxi(int(value), 0)

static func set_attack_power_ranged(u: CombatantState, value: int) -> void:
	if !u:
		return
	u.apr = maxi(int(value), 0)
