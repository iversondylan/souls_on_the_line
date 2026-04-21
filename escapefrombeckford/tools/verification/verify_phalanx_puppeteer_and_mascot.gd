extends SceneTree

const STATUS_CATALOG := preload("res://statuses/_core/status_catalog.tres")
const BOLSTERED := preload("res://statuses/bolstered.tres")
const FLEETING := preload("res://statuses/fleeting.tres")
const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")
const MIGHT := preload("res://statuses/might.tres")
const PHALANX_GUARD := preload("res://statuses/phalanx_round_guard.tres")
const PHALANX_ROUND_FORTITUDE := preload("res://statuses/phalanx_round_fortitude.tres")
const SMALL := preload("res://statuses/small.tres")
const AMPLIFY := preload("res://statuses/amplify.tres")
const PHALANX_AI := preload("res://combatants/souls/Phalanx/phalanx_ai_profile.tres")
const CRONE_AI := preload("res://combatants/souls/CronePuppeteer/crone_puppeteer_ai_profile.tres")
const MASCOT_AI := preload("res://combatants/souls/SmolderingMascot/smoldering_mascot_ai_profile.tres")

func _init() -> void:
	var exit_code := 0
	var failure := ""

	if !_verify_card_text():
		exit_code = 1
		failure = "card text verification failed"
	elif !_verify_phalanx_behavior():
		exit_code = 1
		failure = "phalanx verification failed"
	elif !_verify_crone_puppeteer_behavior():
		exit_code = 1
		failure = "crone puppeteer verification failed"
	elif !_verify_smoldering_mascot_behavior():
		exit_code = 1
		failure = "smoldering mascot verification failed"

	if exit_code == 0:
		print("Phalanx, Crone Puppeteer, and Smoldering Mascot verification passed.")
	else:
		push_error(failure)

	quit(exit_code)

func _verify_card_text() -> bool:
	var phalanx_card_text := FileAccess.get_file_as_string("res://cards/souls/PhalanxCard/phalanx_card.tres")
	var crone_card_text := FileAccess.get_file_as_string("res://cards/souls/CronePuppeteerCard/crone_puppeteer_card.tres")
	var mascot_card_text := FileAccess.get_file_as_string("res://cards/souls/SmolderingMascotCard/smoldering_mascot_card.tres")
	_assert(!phalanx_card_text.is_empty(), "phalanx card text should load")
	_assert(!crone_card_text.is_empty(), "crone card text should load")
	_assert(!mascot_card_text.is_empty(), "mascot card text should load")
	_assert_equal(
		phalanx_card_text.contains("description = \"Summon a %s/%s %s. The first time each round this takes strike damage, gain 50% reduced damage for the rest of that round. At end of round, gain +2 max health (full).\""),
		true,
		"phalanx card description"
	)
	_assert_equal(
		crone_card_text.contains("description = \"Summon a %s/%s %s. Does not attack; summons a Small, Fleeting 3/3 Patchwork Puppet at the front.\""),
		true,
		"crone card description"
	)
	_assert_equal(
		mascot_card_text.contains("description = \"Summon a %s/%s %s. Deals 1 damage to all targets, applying 1 Amplify to allies.\""),
		true,
		"mascot card description"
	)
	return true

func _verify_phalanx_behavior() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var phalanx_id := runtime.add_combatant_from_data(_make_unit_data("Phalanx", 8, 2, PHALANX_AI), SimBattleAPI.FRIENDLY, -1, false, 8)
	var player_id := runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	var enemy_id := runtime.add_combatant_from_data(_make_unit_data("Enemy", 20, 4), SimBattleAPI.ENEMY, -1, false, 20)
	_assert(phalanx_id > 0 and player_id > 0 and enemy_id > 0, "phalanx test setup")

	_apply_status(api, phalanx_id, PHALANX_GUARD.get_id(), 1)
	_apply_status(api, phalanx_id, PHALANX_ROUND_FORTITUDE.get_id(), 1)
	_assert(api.has_status(phalanx_id, PHALANX_GUARD.get_id()), "phalanx starts armed")
	api.plan_intent(phalanx_id)

	_run_attack(api, enemy_id, 4)
	var phalanx := host.get_main_state().get_unit(phalanx_id)
	_assert(phalanx != null, "phalanx should exist")
	_assert_equal(phalanx.health, 4, "first strike is not reduced")
	_assert_equal(api.get_status_intensity(phalanx_id, BOLSTERED.get_id()), 50, "phalanx gains bolstered after first strike")
	_assert(!api.has_status(phalanx_id, PHALANX_GUARD.get_id()), "phalanx guard is consumed after triggering")

	_run_attack(api, enemy_id, 4)
	_assert_equal(phalanx.health, 2, "later strike in the round is reduced by bolstered")

	SimStatusSystem.on_group_turn_begin(api, SimBattleAPI.FRIENDLY)
	SimStatusSystem.on_player_turn_begin(api, player_id)
	ActionLifecycleSystem.on_player_turn_begin(api, player_id)
	_assert_equal(api.get_status_intensity(phalanx_id, FULL_FORTITUDE.get_id()), 2, "phalanx gains full fortitude at round end boundary")
	_assert_equal(phalanx.max_health, 10, "phalanx gains max health from full fortitude")
	_assert_equal(phalanx.health, 4, "phalanx gains full health with the fortitude")
	_assert_equal(api.get_status_intensity(phalanx_id, PHALANX_GUARD.get_id()), 1, "phalanx guard rearms on player turn start")
	_assert_equal(api.get_status_intensity(phalanx_id, BOLSTERED.get_id()), 0, "bolstered clears on the next round boundary")

	SimStatusSystem.on_group_turn_begin(api, SimBattleAPI.FRIENDLY)
	SimStatusSystem.on_player_turn_begin(api, player_id)
	_assert_equal(api.get_status_intensity(phalanx_id, FULL_FORTITUDE.get_id()), 4, "phalanx gains another full fortitude stack next round")
	return true

func _verify_crone_puppeteer_behavior() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var front_ally_id := runtime.add_combatant_from_data(_make_unit_data("Front Ally", 4, 1), SimBattleAPI.FRIENDLY, -1, false, 4)
	var player_id := runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	var crone_id := runtime.add_combatant_from_data(_make_unit_data("Crone Puppeteer", 3, 0, CRONE_AI), SimBattleAPI.FRIENDLY, -1, false, 3)
	var enemy_id := runtime.add_combatant_from_data(_make_unit_data("Enemy", 20, 4), SimBattleAPI.ENEMY, -1, false, 20)
	_assert(front_ally_id > 0 and player_id > 0 and crone_id > 0 and enemy_id > 0, "crone test setup")

	var chunk := _run_scoped_actor_turn(runtime, api, crone_id, 1, SimBattleAPI.FRIENDLY)
	var summoned_ids := api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false).filter(func(id: int) -> bool:
		return int(id) != int(front_ally_id) and int(id) != int(player_id) and int(id) != int(crone_id)
	)
	_assert_equal(summoned_ids.size(), 1, "crone summons exactly one puppet")
	var puppet_id := int(summoned_ids[0])
	var puppet := host.get_main_state().get_unit(puppet_id)
	_assert(puppet != null, "patchwork puppet should exist")
	_assert_equal(puppet.max_health, 3, "patchwork puppet max health")
	_assert_equal(puppet.health, 3, "patchwork puppet starts full")
	_assert_equal(puppet.ap, 3, "patchwork puppet attack power")
	_assert_equal(int(api.get_rank_in_group(puppet_id)), 0, "patchwork puppet is summoned at the front")
	_assert(api.has_status(puppet_id, SMALL.get_id()), "patchwork puppet gets Small")
	_assert(api.has_status(puppet_id, FLEETING.get_id()), "patchwork puppet gets Fleeting")
	_assert_equal(_count_events_of_type(chunk, BattleEvent.Type.STRIKE), 0, "crone turn has no attack strikes")
	return true

func _verify_smoldering_mascot_behavior() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var ally_id := runtime.add_combatant_from_data(_make_unit_data("Friendly Ally", 6, 1), SimBattleAPI.FRIENDLY, -1, false, 6)
	var player_id := runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	var mascot_id := runtime.add_combatant_from_data(_make_unit_data("Smoldering Mascot", 3, 1, MASCOT_AI), SimBattleAPI.FRIENDLY, -1, false, 3)
	var enemy_a_id := runtime.add_combatant_from_data(_make_unit_data("Enemy A", 10, 2), SimBattleAPI.ENEMY, -1, false, 10)
	var enemy_b_id := runtime.add_combatant_from_data(_make_unit_data("Enemy B", 10, 2), SimBattleAPI.ENEMY, -1, false, 10)
	_assert(ally_id > 0 and player_id > 0 and mascot_id > 0 and enemy_a_id > 0 and enemy_b_id > 0, "mascot test setup")

	_apply_status(api, mascot_id, MIGHT.get_id(), 1)
	_apply_status(api, ally_id, BOLSTERED.get_id(), 50)
	_apply_status(api, player_id, BOLSTERED.get_id(), 50)
	_apply_status(api, mascot_id, BOLSTERED.get_id(), 50)

	var chunk := _run_scoped_actor_turn(runtime, api, mascot_id, 1, SimBattleAPI.FRIENDLY)
	var ally := host.get_main_state().get_unit(ally_id)
	var player := host.get_main_state().get_unit(player_id)
	var mascot := host.get_main_state().get_unit(mascot_id)
	var enemy_a := host.get_main_state().get_unit(enemy_a_id)
	var enemy_b := host.get_main_state().get_unit(enemy_b_id)
	_assert(ally != null and player != null and mascot != null and enemy_a != null and enemy_b != null, "mascot units should exist")

	_assert_equal(ally.health, 5, "friendly ally takes 1 unmodified friendly-fire damage")
	_assert_equal(player.health, 19, "player takes 1 unmodified friendly-fire damage")
	_assert_equal(mascot.health, 2, "mascot takes 1 unmodified self damage")
	_assert_equal(api.get_status_intensity(ally_id, AMPLIFY.get_id()), 1, "friendly ally gains amplify")
	_assert_equal(api.get_status_intensity(player_id, AMPLIFY.get_id()), 1, "player gains amplify")
	_assert_equal(api.get_status_intensity(mascot_id, AMPLIFY.get_id()), 1, "mascot gains amplify")
	_assert_equal(enemy_a.health, 7, "enemy hit uses normal modifiers after amplify")
	_assert_equal(enemy_b.health, 7, "all enemies are hit after amplify")

	_assert_equal(_count_top_level_effect_packages(chunk), 3, "mascot action emits three top-level effect packages")
	return true

func _run_scoped_actor_turn(runtime: SimRuntime, api: SimBattleAPI, actor_id: int, turn_id: int, group_index: int) -> Array[BattleEvent]:
	var log: BattleEventLog = api.state.events if api != null and api.state != null else null
	_assert(log != null, "battle event log should exist")
	log.clear()
	api.writer.set_turn_context(int(turn_id), int(group_index), int(actor_id))
	var scope := api.writer.scope_begin(Scope.Kind.ACTOR_TURN, "actor=%d" % actor_id, actor_id)
	_assert(scope != null, "actor turn scope should open")
	api.writer.emit_actor_begin(actor_id)
	runtime.run_npc_turn(actor_id)
	api.writer.emit_actor_end(actor_id)
	api.writer.scope_end(scope)

	return log.read_range(0, log.size())

func _count_events_of_type(events: Array[BattleEvent], event_type: int) -> int:
	var count := 0
	for event in events:
		if event != null and int(event.type) == int(event_type):
			count += 1
	return count

func _count_top_level_effect_packages(events: Array[BattleEvent]) -> int:
	var actor_turn_scope_id := 0
	var package_indexes := {}
	for event in events:
		if event == null or int(event.type) != int(BattleEvent.Type.SCOPE_BEGIN):
			continue
		var data := event.data if event.data != null else {}
		var scope_kind := int(data.get(Keys.SCOPE_KIND, event.scope_kind))
		var scope_id := int(data.get(Keys.SCOPE_ID, event.scope_id))
		var parent_scope_id := int(data.get(Keys.PARENT_SCOPE_ID, event.parent_scope_id))
		if scope_kind == int(Scope.Kind.ACTOR_TURN) and actor_turn_scope_id <= 0:
			actor_turn_scope_id = scope_id
			continue
		if actor_turn_scope_id <= 0 or parent_scope_id != actor_turn_scope_id:
			continue
		if !data.has(Keys.EFFECT_PACKAGE_INDEX):
			continue
		package_indexes[int(data.get(Keys.EFFECT_PACKAGE_INDEX, -1))] = true
	return package_indexes.size()

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

func _apply_status(api: SimBattleAPI, target_id: int, status_id: StringName, intensity: int, duration: int = 0) -> void:
	var ctx := StatusContext.new()
	ctx.source_id = target_id
	ctx.target_id = target_id
	ctx.status_id = status_id
	ctx.intensity = intensity
	ctx.duration = duration
	api.apply_status(ctx)

func _run_attack(api: SimBattleAPI, attacker_id: int, damage: int) -> void:
	var attack_ctx := AttackContext.new()
	attack_ctx.api = api
	attack_ctx.runtime = api.runtime
	attack_ctx.attacker_id = attacker_id
	attack_ctx.source_id = attacker_id
	attack_ctx.base_damage = damage
	attack_ctx.attack_mode = int(Attack.Mode.MELEE)
	attack_ctx.targeting = int(Attack.Targeting.STANDARD)
	attack_ctx.targeting_ctx = TargetingContext.new()
	attack_ctx.targeting_ctx.api = api
	attack_ctx.targeting_ctx.source_id = attacker_id
	attack_ctx.targeting_ctx.target_type = int(Attack.Targeting.STANDARD)
	attack_ctx.targeting_ctx.attack_mode = int(Attack.Mode.MELEE)
	api.runtime.run_attack(attack_ctx)

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
