extends SceneTree

const BattleRemovalLog := preload("res://battle/sim/containers/battle_removal_log.gd")
const RemovalRecord := preload("res://battle/sim/containers/removal_record.gd")
const TurnState := preload("res://battle/sim/containers/turn_state.gd")


func _init() -> void:
	_verify_state_helpers()
	_verify_source_wiring()
	_verify_seance_resources()
	print("verify_seance_removal_history: ok")
	quit()


func _verify_state_helpers() -> void:
	var turn := TurnState.new()
	turn.round_number = 3
	turn.group_turn_number = 5
	var turn_clone := turn.clone()
	assert(int(turn_clone.round_number) == 3, "TurnState clone should preserve round_number.")
	assert(int(turn_clone.group_turn_number) == 5, "TurnState clone should preserve group_turn_number.")

	var log := BattleRemovalLog.new()
	var death := RemovalRecord.new()
	death.removal_type = Removal.Type.DEATH
	death.round_number = 2
	death.group_turn_number = 4
	death.group_index = 0
	death.completed_group_turns_lived = 3
	log.append(death)

	var fade := RemovalRecord.new()
	fade.removal_type = Removal.Type.FADE
	fade.round_number = 2
	fade.group_turn_number = 4
	fade.group_index = 0
	log.append(fade)

	assert(log.count_by_round(Removal.Type.DEATH, 2) == 1, "Removal log should count deaths by round.")
	assert(log.count_by_round(Removal.Type.FADE, 2) == 1, "Removal log should count fades separately.")
	assert(log.count_by_group_turn(Removal.Type.DEATH, 4, 0) == 1, "Removal log should count by group turn.")

	var log_clone := log.clone()
	assert(log_clone.records.size() == 2, "Removal log clone should preserve records.")
	assert(
		int(log_clone.records[0].completed_group_turns_lived) == 3,
		"Removal log clone should preserve removed combatant age."
	)


func _verify_source_wiring() -> void:
	_expect_file_contains(
		"res://battle/sim/containers/combatant_state.gd",
		[
			"var completed_group_turns_lived: int = 0",
			"c.completed_group_turns_lived = completed_group_turns_lived",
		]
	)
	_expect_file_contains(
		"res://battle/sim/operators/sim_runtime.gd",
		[
			"_sync_turn_counters_from_engine",
			"_increment_survivor_group_turn_age",
			"completed_group_turns_lived += 1",
		]
	)
	_expect_file_contains(
		"res://battle/sim/operators/sim_battle_api.gd",
		[
			"func count_previous_round_deaths",
			"func _log_removal",
			"state.removal_log.append(record)",
			"record.completed_group_turns_lived",
		]
	)
	_expect_file_contains(
		"res://core/utils/TextUtils.gd",
		[
			"ctx.api = api",
			"ctx.card_data = card_data",
		]
	)


func _verify_seance_resources() -> void:
	_expect_file_contains(
		"res://cards/convocations/Seance/seance.tres",
		[
			"id = &\"seance\"",
			"name = \"Seance\"",
			"target_type = 3",
			"rarity = 0",
			"cost = 1",
			"haunting.png",
			"+%s bonus damage. Draw 1.",
		]
	)
	_expect_file_contains(
		"res://cards/convocations/Seance/seance_action.gd",
		[
			"count_previous_round_deaths",
			"ENERGY_SURGE.get_id()",
			"status_ctx.stacks = bonus",
			"DrawContext.new()",
			"return str(_get_bonus(api))",
		]
	)
	_expect_file_contains("res://character_profiles/Cole/cole_draftable_cards.tres", ["res://cards/convocations/Seance/seance.tres"])
	_expect_file_contains("res://character_profiles/Cole/one_of_each_card.tres", ["res://cards/convocations/Seance/seance.tres"])


func _expect_file_contains(path: String, needles: Array[String]) -> void:
	var text := FileAccess.get_file_as_string(path)
	assert(!text.is_empty(), "%s should be readable." % path)
	for needle in needles:
		assert(text.find(needle) != -1, "%s should contain %s." % [path, needle])
