extends SceneTree

const STATUS_CATALOG := preload("res://statuses/_core/status_catalog.tres")
const GROUNDING_ACCORD := preload("res://statuses/grounding_accord.tres")
const AWASE := preload("res://statuses/awase.tres")
const ABSORB := preload("res://statuses/absorb.tres")
const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")
const OTHER_SIDE_MODEL := preload("res://npc_ai/insert_index/other_side_of_player_insert_index_model.tres")
const MOVE_SEQUENCE := preload("res://npc_ai/npc_move_sequence.tres")


func _init() -> void:
	var exit_code := 0
	var failure := ""

	if !_verify_card_text():
		exit_code = 1
		failure = "card text verification failed"
	elif !_verify_grounding_accord_and_awase():
		exit_code = 1
		failure = "manticore status verification failed"
	elif !_verify_other_side_of_player_move_model():
		exit_code = 1
		failure = "ten-marten move model verification failed"

	if exit_code == 0:
		print("Manticore and Ten-Marten verification passed.")
	else:
		push_error(failure)

	quit(exit_code)


func _verify_card_text() -> bool:
	var manticore_card_text := FileAccess.get_file_as_string("res://cards/souls/ManticoreOfTheMeanCard/manticore_of_the_mean_card.tres")
	var ten_marten_card_text := FileAccess.get_file_as_string("res://cards/souls/TenMartenCard/ten_marten_card.tres")
	_assert(!manticore_card_text.is_empty(), "manticore card text should load")
	_assert(!ten_marten_card_text.is_empty(), "ten-marten card text should load")
	_assert_equal(
		manticore_card_text.contains("description = \"Summon a %s/%s %s. The first time each round you play your second Convocation, this gains Absorb. Whenever Absorb on this prevents damage, gain Full Fortitude.\""),
		true,
		"manticore card description text"
	)
	_assert_equal(
		ten_marten_card_text.contains("description = \"Summon a %s/%s %s. On attack: move to the other side of the player.\""),
		true,
		"ten-marten card description text"
	)
	return true


func _verify_grounding_accord_and_awase() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var manticore_id := runtime.add_combatant_from_data(_make_unit_data("Manticore", 8, 3), SimBattleAPI.FRIENDLY, -1, false, 8)
	var player_id := runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	var enemy_id := runtime.add_combatant_from_data(_make_unit_data("Enemy", 20, 4), SimBattleAPI.ENEMY, -1, false, 20)
	_assert(manticore_id > 0 and player_id > 0 and enemy_id > 0, "manticore test setup")

	_apply_status(api, manticore_id, GROUNDING_ACCORD.get_id(), 1)
	_apply_status(api, manticore_id, AWASE.get_id(), 1)

	_play_convocation(api, player_id)
	_assert_equal(api.get_status_intensity(manticore_id, ABSORB.get_id()), 0, "first convocation does not grant absorb")

	_play_convocation(api, player_id)
	_assert_equal(api.get_status_intensity(manticore_id, ABSORB.get_id()), 1, "second convocation grants absorb")

	_play_convocation(api, player_id)
	_assert_equal(api.get_status_intensity(manticore_id, ABSORB.get_id()), 1, "third convocation does not add extra absorb")

	var manticore := host.get_main_state().get_unit(manticore_id)
	_assert(manticore != null, "manticore unit should exist")
	_assert_equal(manticore.max_health, 8, "manticore max health baseline")
	_assert_equal(manticore.health, 8, "manticore health baseline")
	_assert_equal(api.get_status_intensity(manticore_id, FULL_FORTITUDE.get_id()), 0, "manticore does not start with full fortitude")

	var blocked_hit := DamageContext.new()
	blocked_hit.source_id = enemy_id
	blocked_hit.target_id = manticore_id
	blocked_hit.base_amount = 4
	blocked_hit.tags.append(&"strike_damage")
	api.resolve_damage_immediate(blocked_hit)

	_assert_equal(api.get_status_intensity(manticore_id, ABSORB.get_id()), 0, "absorb is consumed after preventing damage")
	_assert_equal(api.get_status_intensity(manticore_id, FULL_FORTITUDE.get_id()), 1, "awase grants full fortitude when absorb prevents damage")
	_assert_equal(manticore.health, 9, "full fortitude fills the added health")
	_assert_equal(manticore.max_health, 9, "full fortitude adds max health when absorb prevents damage")

	var normal_hit := DamageContext.new()
	normal_hit.source_id = enemy_id
	normal_hit.target_id = manticore_id
	normal_hit.base_amount = 3
	normal_hit.tags.append(&"strike_damage")
	api.resolve_damage_immediate(normal_hit)
	_assert_equal(manticore.health, 6, "normal strike damage applies without absorb")
	_assert_equal(api.get_status_intensity(manticore_id, FULL_FORTITUDE.get_id()), 1, "normal damage without absorb does not add fortitude")

	api.state.turn.round = 2
	SimStatusSystem.on_player_turn_begin(api, player_id)
	_play_convocation(api, player_id)
	_play_convocation(api, player_id)
	_assert_equal(api.get_status_intensity(manticore_id, ABSORB.get_id()), 1, "grounding accord can trigger again next round")
	return true


func _verify_other_side_of_player_move_model() -> bool:
	var host := _make_host()
	var runtime := host.get_main_runtime()
	var api := host.get_main_api()

	var behind_id := runtime.add_combatant_from_data(_make_unit_data("Behind Ten-Marten", 3, 3), SimBattleAPI.FRIENDLY, -1, false, 3)
	var player_id := runtime.add_combatant_from_data(_make_unit_data("Player", 20), SimBattleAPI.FRIENDLY, -1, true, 20)
	var ally_id := runtime.add_combatant_from_data(_make_unit_data("Other Ally", 3, 1), SimBattleAPI.FRIENDLY, -1, false, 3)
	_assert(behind_id > 0 and player_id > 0 and ally_id > 0, "move model setup")

	var ctx_behind := _build_ai_ctx(api, runtime, behind_id)
	OTHER_SIDE_MODEL.change_params_sim(ctx_behind)
	_assert_equal(int(ctx_behind.params.get(Keys.TO_INDEX, -1)), int(api.get_rank_in_group(player_id)), "front side target index from ahead of player")
	MOVE_SEQUENCE.execute(ctx_behind)
	_assert_equal(int(api.get_rank_in_group(behind_id)), int(api.get_rank_in_group(player_id)) + 1, "front-side unit moves to immediately behind player")

	var front_id := runtime.add_combatant_from_data(_make_unit_data("Front Ten-Marten", 3, 3), SimBattleAPI.FRIENDLY, -1, false, 3)
	_assert(front_id > 0, "front move model spawn")
	var move_front := MoveContext.new()
	move_front.actor_id = front_id
	move_front.target_id = front_id
	move_front.move_type = MoveContext.MoveType.INSERT_AT_INDEX
	move_front.index = 0
	move_front.reason = "test_front_case_setup"
	runtime.run_move(move_front)
	_assert_equal(int(api.get_rank_in_group(front_id)), 0, "front case setup index")
	_assert_equal(int(api.get_rank_in_group(player_id)), 1, "player index in front case")

	var ctx_front := _build_ai_ctx(api, runtime, front_id)
	OTHER_SIDE_MODEL.change_params_sim(ctx_front)
	_assert_equal(int(ctx_front.params.get(Keys.TO_INDEX, -1)), int(api.get_rank_in_group(player_id)), "front side target index")
	MOVE_SEQUENCE.execute(ctx_front)
	_assert_equal(int(api.get_rank_in_group(front_id)), int(api.get_rank_in_group(player_id)) - 1, "behind-side unit moves to immediately in front of player")

	var far_id := runtime.add_combatant_from_data(_make_unit_data("Far Ten-Marten", 3, 3), SimBattleAPI.FRIENDLY, -1, false, 3)
	_assert(far_id > 0, "far move model spawn")
	var move_far := MoveContext.new()
	move_far.actor_id = far_id
	move_far.target_id = far_id
	move_far.move_type = MoveContext.MoveType.INSERT_AT_INDEX
	move_far.index = 0
	move_far.reason = "test_far_case_setup"
	runtime.run_move(move_far)
	var ctx_far := _build_ai_ctx(api, runtime, far_id)
	OTHER_SIDE_MODEL.change_params_sim(ctx_far)
	_assert_equal(bool(ctx_far.params.get(Keys.SEQUENCE_EXECUTABLE, false)), true, "non-adjacent front-side case is executable")
	_assert_equal(int(ctx_far.params.get(Keys.TO_INDEX, -1)), int(api.get_rank_in_group(player_id)), "non-adjacent front-side case targets the player's far side")
	MOVE_SEQUENCE.execute(ctx_far)

	var player_rank_after_far := int(api.get_rank_in_group(player_id))
	_assert_equal(int(api.get_rank_in_group(far_id)), player_rank_after_far + 1, "non-adjacent front-side case moves to immediately behind player")

	var rear_id := runtime.add_combatant_from_data(_make_unit_data("Rear Ten-Marten", 3, 3), SimBattleAPI.FRIENDLY, -1, false, 3)
	_assert(rear_id > 0, "rear move model spawn")
	var move_rear := MoveContext.new()
	move_rear.actor_id = rear_id
	move_rear.target_id = rear_id
	move_rear.move_type = MoveContext.MoveType.INSERT_AT_INDEX
	move_rear.index = 999
	move_rear.reason = "test_rear_case_setup"
	runtime.run_move(move_rear)
	var ctx_rear := _build_ai_ctx(api, runtime, rear_id)
	OTHER_SIDE_MODEL.change_params_sim(ctx_rear)
	_assert_equal(bool(ctx_rear.params.get(Keys.SEQUENCE_EXECUTABLE, false)), true, "non-adjacent behind-side case is executable")
	_assert_equal(int(ctx_rear.params.get(Keys.TO_INDEX, -1)), int(api.get_rank_in_group(player_id)), "non-adjacent behind-side case targets the player's front side")
	MOVE_SEQUENCE.execute(ctx_rear)
	_assert_equal(int(api.get_rank_in_group(rear_id)), int(api.get_rank_in_group(player_id)) - 1, "non-adjacent behind-side case moves to immediately in front of player")
	return true


func _build_ai_ctx(api: SimBattleAPI, runtime: SimRuntime, actor_id: int) -> NPCAIContext:
	var ctx := NPCAIContext.new()
	ctx.api = api
	ctx.runtime = runtime
	ctx.cid = actor_id
	ctx.combatant_state = api.state.get_unit(actor_id)
	ctx.combatant_data = ctx.combatant_state.combatant_data if ctx.combatant_state != null else null
	ctx.params = {}
	ctx.state = ctx.combatant_state.ai_state if ctx.combatant_state != null else {}
	return ctx


func _play_convocation(api: SimBattleAPI, source_id: int) -> void:
	var card := CardData.new()
	card.card_type = CardData.CardType.CONVOCATION
	card.name = "Test Convocation"
	SimStatusSystem.on_card_played(api, source_id, card)


func _make_host() -> SimHost:
	var host := SimHost.new()
	host.status_catalog = STATUS_CATALOG
	host.init_from_seeds(123, 456)
	return host


func _make_unit_data(unit_name: String, health: int, ap: int = 0) -> CombatantData:
	var data := CombatantData.new()
	data.name = unit_name
	data.max_health = health
	data.ap = ap
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
