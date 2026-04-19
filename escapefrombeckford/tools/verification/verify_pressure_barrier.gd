extends SceneTree

const STATUS_CATALOG := preload("res://statuses/_core/status_catalog.tres")
const HEAVY_ATTACK := preload("res://statuses/heavy_attack.tres")
const PRESSURE_BARRIER := preload("res://statuses/pressure_barrier.tres")
const PRESSURE_BARRIER_CARD := preload("res://cards/convocations/PressureBarrier/pressure_barrier_data.tres")
const CRYSTAL_BARRIER_CARD := preload("res://cards/convocations/CrystalBarrier/crystal_barrier.tres")
const SCARAB_SUBSTITUTION_CARD := preload("res://cards/convocations/ScarabSubstitution/scarab_substitution.tres")
const INTERCEPTION_CARD := preload("res://cards/convocations/Interception/interception.tres")

const BASE_PRESSURE_BARRIER_TEXT := "Hits on this unit have their damage reduced by %s."
const CRYSTAL_BARRIER_TEXT := "An ally gains Absorb, and hits on them have their damage reduced by %s until your next turn."
const SCARAB_SUBSTITUTION_TEXT := "Sacrifice an ally. Summon a 1/3 Shield Mite at the front. It negates the next hit, and hits on it have their damage reduced by 1 until your next turn."
const INTERCEPTION_TEXT := "Sacrifice an ally. Move the frontmost remaining ally to the front. They negate the next hit, and hits on them have their damage reduced by 2 until your next turn."


func _init() -> void:
	var exit_code := 0
	var failure := ""

	if !_verify_text():
		exit_code = 1
		failure = "text verification failed"
	elif !_verify_heavy_cleave_pressure_barrier():
		exit_code = 1
		failure = "heavy cleave verification failed"
	elif !_verify_multi_target_hit_scope():
		exit_code = 1
		failure = "multi-target hit-scope verification failed"

	if exit_code == 0:
		print("Pressure Barrier verification passed.")
	else:
		push_error(failure)

	quit(exit_code)


func _verify_text() -> bool:
	_assert_equal(PRESSURE_BARRIER.get_tooltip(2, 0), "Hits on this unit have their damage reduced by 2.", "status tooltip")
	_assert_equal(PRESSURE_BARRIER_CARD.description, BASE_PRESSURE_BARRIER_TEXT, "pressure barrier card text")
	_assert_equal(CRYSTAL_BARRIER_CARD.description, CRYSTAL_BARRIER_TEXT, "crystal barrier text")
	_assert_equal(SCARAB_SUBSTITUTION_CARD.description, SCARAB_SUBSTITUTION_TEXT, "scarab substitution text")
	_assert_equal(INTERCEPTION_CARD.description, INTERCEPTION_TEXT, "interception text")
	return true


func _verify_heavy_cleave_pressure_barrier() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var attacker_id := runtime.add_combatant_from_data(_make_unit_data("Heavy Attacker", 20), SimBattleAPI.FRIENDLY, -1, false, 20)
	var front_id := runtime.add_combatant_from_data(_make_unit_data("Front Target", 2), SimBattleAPI.ENEMY, -1, false, 2)
	var rear_id := runtime.add_combatant_from_data(_make_unit_data("Rear Target", 10), SimBattleAPI.ENEMY, -1, false, 10)

	_apply_status(api, attacker_id, HEAVY_ATTACK.get_id(), 1)
	_apply_status(api, front_id, PRESSURE_BARRIER.get_id(), 2)

	var attack_ctx := AttackContext.new()
	attack_ctx.api = api
	attack_ctx.attacker_id = attacker_id
	attack_ctx.source_id = attacker_id
	attack_ctx.base_damage = 7
	attack_ctx.attack_mode = int(Attack.Mode.MELEE)
	attack_ctx.targeting = int(Attack.Targeting.STANDARD)

	_assert(runtime.run_attack(attack_ctx), "heavy cleave attack should resolve")

	var front := host.get_main_state().get_unit(front_id)
	var rear := host.get_main_state().get_unit(rear_id)
	_assert(front != null, "front unit missing after heavy cleave test")
	_assert(rear != null, "rear unit missing after heavy cleave test")
	_assert_equal(front.health, 0, "front target health after heavy cleave")
	_assert_equal(rear.health, 7, "rear target health after heavy cleave")
	return true


func _verify_multi_target_hit_scope() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var attacker_id := runtime.add_combatant_from_data(_make_unit_data("Wide Attacker", 20), SimBattleAPI.FRIENDLY, -1, false, 20)
	var shielded_id := runtime.add_combatant_from_data(_make_unit_data("Shielded Target", 10), SimBattleAPI.ENEMY, -1, false, 10)
	var unshielded_id := runtime.add_combatant_from_data(_make_unit_data("Plain Target", 10), SimBattleAPI.ENEMY, -1, false, 10)

	_apply_status(api, shielded_id, PRESSURE_BARRIER.get_id(), 2)

	var attack_ctx := AttackContext.new()
	attack_ctx.api = api
	attack_ctx.attacker_id = attacker_id
	attack_ctx.source_id = attacker_id
	attack_ctx.base_damage = 5
	attack_ctx.attack_mode = int(Attack.Mode.MELEE)
	attack_ctx.targeting = int(Attack.Targeting.ENEMIES)

	_assert(runtime.run_attack(attack_ctx), "multi-target attack should resolve")

	var shielded := host.get_main_state().get_unit(shielded_id)
	var unshielded := host.get_main_state().get_unit(unshielded_id)
	_assert(shielded != null, "shielded unit missing after multi-target test")
	_assert(unshielded != null, "unshielded unit missing after multi-target test")
	_assert_equal(shielded.health, 7, "shielded target health after multi-target test")
	_assert_equal(unshielded.health, 5, "unshielded target health after multi-target test")
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


func _apply_status(api: SimBattleAPI, target_id: int, status_id: StringName, intensity: int) -> void:
	var ctx := StatusContext.new()
	ctx.source_id = target_id
	ctx.target_id = target_id
	ctx.status_id = status_id
	ctx.intensity = intensity
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
