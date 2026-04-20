extends SceneTree

const STATUS_CATALOG := preload("res://statuses/_core/status_catalog.tres")
const EMPTY_FORTITUDE := preload("res://statuses/empty_fortitude.tres")
const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")
const MOSSLING_STATUS := preload("res://statuses/mossling_bulwark.tres")
const YGGDRASIL_GUARD := preload("res://statuses/yggdrasil_guard.tres")
const YGGDRASIL_HART_AI := preload("res://combatants/souls/YggdrasilHart/yggdrasil_hart_ai_profile.tres")


func _init() -> void:
	var exit_code := 0
	var failure := ""

	if !_verify_card_text():
		exit_code = 1
		failure = "card text verification failed"
	elif !_verify_fortitude_math():
		exit_code = 1
		failure = "fortitude math verification failed"
	elif !_verify_mossling_behavior():
		exit_code = 1
		failure = "mossling verification failed"
	elif !_verify_yggdrasil_guard_behavior():
		exit_code = 1
		failure = "yggdrasil guard verification failed"

	if exit_code == 0:
		print("Fortitude and Hart verification passed.")
	else:
		push_error(failure)

	quit(exit_code)


func _verify_card_text() -> bool:
	var mossling_card_text := FileAccess.get_file_as_string("res://cards/souls/MosslingBulwarkCard/mossling_bulwark_card.tres")
	var hart_card_text := FileAccess.get_file_as_string("res://cards/souls/YggdrasilHartCard/yggdrasil_hart_card.tres")
	var guard_on_summon_text := FileAccess.get_file_as_string("res://cards/souls/YggdrasilHartCard/yggdrasil_guard_on_summoned_action.tres")
	_assert(!mossling_card_text.is_empty(), "mossling card file should load as text")
	_assert(!hart_card_text.is_empty(), "hart card file should load as text")
	_assert(!guard_on_summon_text.is_empty(), "hart on-summon action file should load as text")
	_assert_equal(
		mossling_card_text.contains("description = \"Summon a %s/%s %s. Deplete. On summon: your frontmost ally gains +2 max health (full). On death: heal your most damaged ally 4.\""),
		true,
		"mossling card description text"
	)
	_assert_equal(
		hart_card_text.contains("description = \"Summon a %s/%s %s. The first time each round this would take strike damage, reduce it by 2. If it survives, gain +2 max health.\""),
		true,
		"hart card description text"
	)
	_assert_equal(
		guard_on_summon_text.contains("intensity = 2"),
		true,
		"hart on-summon guard intensity"
	)
	_assert_equal(
		EMPTY_FORTITUDE.get_tooltip(2, 0),
		"Empty Fortitude: gain +2 max health. Added health is not healed.",
		"empty fortitude tooltip"
	)
	_assert_equal(
		FULL_FORTITUDE.get_tooltip(2, 0),
		"Full Fortitude: gain +2 max health and fill that added health.",
		"full fortitude tooltip"
	)
	return true


func _verify_fortitude_math() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var unit_id := runtime.add_combatant_from_data(_make_unit_data("Fortitude Tester", 3), SimBattleAPI.FRIENDLY, -1, false, 3)

	_apply_status(api, unit_id, EMPTY_FORTITUDE.get_id(), 2)
	var unit := host.get_main_state().get_unit(unit_id)
	_assert(unit != null, "fortitude tester missing")
	_assert_equal(unit.max_health, 5, "empty fortitude max health")
	_assert_equal(unit.health, 3, "empty fortitude current health unchanged")

	var heal_ctx := HealContext.new(unit_id, unit_id, 2, 0.0, 0.0)
	_assert_equal(api.heal(heal_ctx), 2, "heal into empty fortitude headroom")
	_assert_equal(unit.health, 5, "heal after empty fortitude")

	_remove_status(api, unit_id, EMPTY_FORTITUDE.get_id())
	_assert_equal(unit.max_health, 3, "empty fortitude removed max health")
	_assert_equal(unit.health, 3, "empty fortitude removal clamps current health")

	_apply_status(api, unit_id, FULL_FORTITUDE.get_id(), 2)
	_assert_equal(unit.max_health, 5, "full fortitude max health")
	_assert_equal(unit.health, 5, "full fortitude fills added health")

	var damage_ctx := DamageContext.new()
	damage_ctx.target_id = unit_id
	damage_ctx.base_amount = 4
	api.resolve_damage_immediate(damage_ctx)
	_assert_equal(unit.health, 1, "damage before full fortitude removal")

	_remove_status(api, unit_id, FULL_FORTITUDE.get_id())
	_assert_equal(unit.max_health, 3, "full fortitude removed max health")
	_assert_equal(unit.health, 0, "full fortitude lethal removal health")
	_assert(!unit.is_alive(), "full fortitude lethal removal kills")
	return true


func _verify_mossling_behavior() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var ally_front_id := runtime.add_combatant_from_data(_make_unit_data("Front Ally", 3), SimBattleAPI.FRIENDLY, -1, false, 3)
	var ally_tie_a_id := runtime.add_combatant_from_data(_make_unit_data("Tie Ally A", 5), SimBattleAPI.FRIENDLY, -1, false, 2)
	var ally_tie_b_id := runtime.add_combatant_from_data(_make_unit_data("Tie Ally B", 4), SimBattleAPI.FRIENDLY, -1, false, 1)
	var mossling_id := runtime.add_combatant_from_data(_make_unit_data("Mossling", 3), SimBattleAPI.FRIENDLY, -1, false, 3)
	var player_id := runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	_assert(player_id > 0, "player spawn for mossling test")

	_apply_status(api, mossling_id, MOSSLING_STATUS.get_id(), 1)

	var ally_front := host.get_main_state().get_unit(ally_front_id)
	var ally_tie_a := host.get_main_state().get_unit(ally_tie_a_id)
	var ally_tie_b := host.get_main_state().get_unit(ally_tie_b_id)
	_assert_equal(ally_front.max_health, 5, "mossling summon buffs frontmost ally max health")
	_assert_equal(ally_front.health, 5, "mossling summon fills frontmost ally health")

	var removal_ctx := RemovalContext.new()
	removal_ctx.target_id = mossling_id
	removal_ctx.removal_type = Removal.Type.DEATH
	removal_ctx.reason = "test_mossling_death"
	api.resolve_removal(removal_ctx)

	_assert_equal(ally_tie_a.health, 5, "mossling death heals earliest tied damaged ally")
	_assert_equal(ally_tie_b.health, 1, "mossling death leaves later tied ally untouched")
	return true


func _verify_yggdrasil_guard_behavior() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var hart_id := runtime.add_combatant_from_data(_make_unit_data("Yggdrasil Hart", 8, 2, YGGDRASIL_HART_AI), SimBattleAPI.FRIENDLY, -1, false, 8)
	var player_id := runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	var enemy_id := runtime.add_combatant_from_data(_make_unit_data("Enemy", 12, 4), SimBattleAPI.ENEMY, -1, false, 12)
	_assert(hart_id > 0 and player_id > 0 and enemy_id > 0, "hart test setup")

	_apply_status(api, hart_id, YGGDRASIL_GUARD.get_id(), 2)
	_assert(api.has_status(hart_id, YGGDRASIL_GUARD.get_id()), "hart starts with guard on summon")

	_run_attack(api, enemy_id, 4)
	var hart := host.get_main_state().get_unit(hart_id)
	_assert_equal(hart.health, 6, "hart first strike damage reduced by guard")
	_assert_equal(hart.max_health, 10, "hart gains empty fortitude max health after surviving")
	_assert(!api.has_status(hart_id, YGGDRASIL_GUARD.get_id()), "hart guard removes itself after surviving hit")
	_assert_equal(api.get_status_intensity(hart_id, EMPTY_FORTITUDE.get_id()), 2, "hart gains empty fortitude after guard removal")

	_run_attack(api, enemy_id, 4)
	_assert_equal(hart.health, 2, "hart second hit in same round is not reduced")
	_assert_equal(api.get_status_intensity(hart_id, EMPTY_FORTITUDE.get_id()), 2, "hart does not gain a second fortitude stack in same round")

	api.plan_intent(hart_id)
	_assert(api.has_status(hart_id, EMPTY_FORTITUDE.get_id()), "hart still has empty fortitude before rearm")
	hart.statuses.set_token(YGGDRASIL_GUARD.get_id(), 1, 0, false)
	ActionLifecycleSystem.on_player_turn_begin(api, player_id)
	_assert_equal(api.get_status_intensity(hart_id, YGGDRASIL_GUARD.get_id()), 2, "hart guard normalizes back to 2 on player turn start")

	var lethal_host := _make_host()
	var lethal_runtime := lethal_host.get_main_runtime()
	var lethal_api := lethal_host.get_main_api()
	var lethal_hart_id := lethal_runtime.add_combatant_from_data(_make_unit_data("Low Hart", 8, 2, YGGDRASIL_HART_AI), SimBattleAPI.FRIENDLY, -1, false, 1)
	var lethal_player_id := lethal_runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	var lethal_enemy_id := lethal_runtime.add_combatant_from_data(_make_unit_data("Enemy", 12, 4), SimBattleAPI.ENEMY, -1, false, 12)
	_assert(lethal_player_id > 0, "lethal hart player spawn")
	_apply_status(lethal_api, lethal_hart_id, YGGDRASIL_GUARD.get_id(), 2)

	_run_attack(lethal_api, lethal_enemy_id, 4)
	var lethal_hart := lethal_host.get_main_state().get_unit(lethal_hart_id)
	_assert_equal(lethal_hart.health, 0, "lethal hart dies after reduced strike")
	_assert(!lethal_hart.is_alive(), "lethal hart should die")
	_assert_equal(int(lethal_hart.max_health), 8, "lethal hart does not gain empty fortitude max health")
	_assert(!lethal_api.has_status(lethal_hart_id, EMPTY_FORTITUDE.get_id()), "lethal hart does not gain empty fortitude")
	return true


func _make_host() -> SimHost:
	var host := SimHost.new()
	host.status_catalog = STATUS_CATALOG
	host.init_from_seeds(123, 456)
	return host


func _make_unit_data(unit_name: String, health: int, ap: int = 0, ai_profile: NPCAIProfile = null) -> CombatantData:
	var data := CombatantData.new()
	data.name = unit_name
	data.max_health = health
	data.ap = ap
	data.max_mana = 0
	data.ai = ai_profile
	return data


func _apply_status(api: SimBattleAPI, target_id: int, status_id: StringName, intensity: int) -> void:
	var ctx := StatusContext.new()
	ctx.source_id = target_id
	ctx.target_id = target_id
	ctx.status_id = status_id
	ctx.intensity = intensity
	api.apply_status(ctx)


func _remove_status(api: SimBattleAPI, target_id: int, status_id: StringName) -> void:
	var ctx := StatusContext.new()
	ctx.source_id = target_id
	ctx.target_id = target_id
	ctx.status_id = status_id
	api.remove_status(ctx)


func _run_attack(api: SimBattleAPI, attacker_id: int, damage: int) -> void:
	var runtime := api.runtime
	_assert(runtime != null, "runtime missing for attack helper")

	var attack_ctx := AttackContext.new()
	attack_ctx.api = api
	attack_ctx.runtime = runtime
	attack_ctx.attacker_id = attacker_id
	attack_ctx.source_id = attacker_id
	attack_ctx.base_damage = damage
	attack_ctx.base_damage_melee = damage
	attack_ctx.base_damage_ranged = damage
	attack_ctx.attack_mode = int(Attack.Mode.MELEE)
	attack_ctx.targeting = int(Attack.Targeting.STANDARD)
	attack_ctx.reason = "attack_now"
	_assert(runtime.run_attack(attack_ctx), "attack helper should resolve")


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
