extends SceneTree

const STATUS_CATALOG := preload("res://statuses/_core/status_catalog.tres")
const HEAVY_ATTACK := preload("res://statuses/heavy_attack.tres")
const SMALL := preload("res://statuses/small.tres")


func _init() -> void:
	var exit_code := 0
	var failure := ""

	if !_verify_small_only_stops_after_one_cleave():
		exit_code = 1
		failure = "small cleave stop verification failed"
	elif !_verify_heavy_still_chains():
		exit_code = 1
		failure = "heavy cleave continuation verification failed"

	if exit_code == 0:
		print("Small cleave verification passed.")
	else:
		push_error(failure)

	quit(exit_code)


func _verify_small_only_stops_after_one_cleave() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var attacker_id := runtime.add_combatant_from_data(_make_unit_data("Standard Attacker", 20), SimBattleAPI.FRIENDLY, -1, false, 20)
	var front_id := runtime.add_combatant_from_data(_make_unit_data("Small Front", 2), SimBattleAPI.ENEMY, -1, false, 2)
	var middle_id := runtime.add_combatant_from_data(_make_unit_data("Middle Target", 3), SimBattleAPI.ENEMY, -1, false, 3)
	var rear_id := runtime.add_combatant_from_data(_make_unit_data("Rear Target", 4), SimBattleAPI.ENEMY, -1, false, 4)

	_apply_status(api, front_id, SMALL.get_id(), 1)

	var attack_ctx := _make_attack_context(api, attacker_id, 7)
	_assert(runtime.run_attack(attack_ctx), "small cleave attack should resolve")

	var front := host.get_main_state().get_unit(front_id)
	var middle := host.get_main_state().get_unit(middle_id)
	var rear := host.get_main_state().get_unit(rear_id)
	_assert(front != null, "front unit missing after small cleave test")
	_assert(middle != null, "middle unit missing after small cleave test")
	_assert(rear != null, "rear unit missing after small cleave test")
	_assert_equal(front.health, 0, "front target health after small cleave")
	_assert_equal(middle.health, 0, "middle target health after small cleave")
	_assert_equal(rear.health, 4, "rear target health after small cleave")
	return true


func _verify_heavy_still_chains() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var attacker_id := runtime.add_combatant_from_data(_make_unit_data("Heavy Attacker", 20), SimBattleAPI.FRIENDLY, -1, false, 20)
	var front_id := runtime.add_combatant_from_data(_make_unit_data("Front Target", 2), SimBattleAPI.ENEMY, -1, false, 2)
	var middle_id := runtime.add_combatant_from_data(_make_unit_data("Middle Target", 3), SimBattleAPI.ENEMY, -1, false, 3)
	var rear_id := runtime.add_combatant_from_data(_make_unit_data("Rear Target", 4), SimBattleAPI.ENEMY, -1, false, 4)

	_apply_status(api, attacker_id, HEAVY_ATTACK.get_id(), 1)

	var attack_ctx := _make_attack_context(api, attacker_id, 7)
	_assert(runtime.run_attack(attack_ctx), "heavy cleave attack should resolve")

	var front := host.get_main_state().get_unit(front_id)
	var middle := host.get_main_state().get_unit(middle_id)
	var rear := host.get_main_state().get_unit(rear_id)
	_assert(front != null, "front unit missing after heavy cleave chain test")
	_assert(middle != null, "middle unit missing after heavy cleave chain test")
	_assert(rear != null, "rear unit missing after heavy cleave chain test")
	_assert_equal(front.health, 0, "front target health after heavy cleave chain")
	_assert_equal(middle.health, 0, "middle target health after heavy cleave chain")
	_assert_equal(rear.health, 2, "rear target health after heavy cleave chain")
	return true


func _make_host() -> SimHost:
	var host := SimHost.new()
	host.status_catalog = STATUS_CATALOG
	host.init_from_seeds(123, 456)
	return host


func _make_unit_data(unit_name: String, health: int) -> CombatantData:
	var data := CombatantData.new()
	data.name = unit_name
	data.max_health = health
	data.ap = 0
	data.max_mana = 0
	return data


func _make_attack_context(api: SimBattleAPI, attacker_id: int, base_damage: int) -> AttackContext:
	var attack_ctx := AttackContext.new()
	attack_ctx.api = api
	attack_ctx.attacker_id = attacker_id
	attack_ctx.source_id = attacker_id
	attack_ctx.base_damage = base_damage
	attack_ctx.attack_mode = int(Attack.Mode.MELEE)
	attack_ctx.targeting = int(Attack.Targeting.STANDARD)
	return attack_ctx


func _apply_status(api: SimBattleAPI, target_id: int, status_id: StringName, stacks: int) -> void:
	var ctx := StatusContext.new()
	ctx.source_id = target_id
	ctx.target_id = target_id
	ctx.status_id = status_id
	ctx.stacks = stacks
	api.apply_status(ctx)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	assert(condition, message)


func _assert_equal(actual, expected, label: String) -> void:
	if actual == expected:
		return
	var message := "%s: expected %s, got %s" % [label, str(expected), str(actual)]
	push_error(message)
	assert(false, message)
