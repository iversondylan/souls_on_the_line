extends SceneTree

const DRAW_CONTEXT_PATH := "res://battle/contexts/draw_context.gd"
const SIM_RUNTIME_PATH := "res://battle/sim/operators/sim_runtime.gd"
const CARD_BINS_PATH := "res://battle/card_mgmt/battle_card_bins.gd"
const BATTLE_SCENE_PATH := "res://battle/battle.tscn"
const TUTORIAL_ENCOUNTER_PATH := "res://encounters/tutorial/tutorial_encounter.tres"


func _initialize() -> void:
	var failures: Array[String] = []

	_verify_draw_context_flag(failures)
	_verify_runtime_marks_exact_override(failures)
	_verify_card_bins_short_circuit(failures)
	_verify_battle_defaults(failures)
	_verify_tutorial_authored_steps(failures)

	if failures.is_empty():
		print("TUTORIAL DRAW OVERRIDE VERIFY OK")
		quit()
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_draw_context_flag(failures: Array[String]) -> void:
	var text := _read_text(DRAW_CONTEXT_PATH, failures)
	if text.is_empty():
		return
	if !text.contains("var exact_draw_amount: bool = false"):
		failures.append("draw_context: missing exact_draw_amount flag")


func _verify_runtime_marks_exact_override(failures: Array[String]) -> void:
	var text := _read_text(SIM_RUNTIME_PATH, failures)
	if text.is_empty():
		return
	if !text.contains("if int(draw_amount_override) >= 0:"):
		failures.append("sim_runtime: missing authored draw override branch")
	if !text.contains("draw_ctx.amount = maxi(int(draw_amount_override), 0)"):
		failures.append("sim_runtime: missing authored draw amount assignment")
	if !text.contains("draw_ctx.exact_draw_amount = true"):
		failures.append("sim_runtime: missing exact draw override marker")


func _verify_card_bins_short_circuit(failures: Array[String]) -> void:
	var text := _read_text(CARD_BINS_PATH, failures)
	if text.is_empty():
		return
	if !text.contains("if String(ctx.reason) != \"player_turn_refill\":"):
		failures.append("battle_card_bins: missing player_turn_refill reason gate")
	if !text.contains("if bool(ctx.exact_draw_amount):"):
		failures.append("battle_card_bins: missing exact_draw_amount guard")
	if !text.contains("return base_amount"):
		failures.append("battle_card_bins: missing base_amount return for exact draws")


func _verify_battle_defaults(failures: Array[String]) -> void:
	var text := _read_text(BATTLE_SCENE_PATH, failures)
	if text.is_empty():
		return
	if !text.contains("player_turn_draw_type = 2"):
		failures.append("battle.tscn: expected player_turn_draw_type = 2 (GREATER_OF)")
	if !text.contains("player_turn_draw_amount = 4"):
		failures.append("battle.tscn: expected player_turn_draw_amount = 4")


func _verify_tutorial_authored_steps(failures: Array[String]) -> void:
	var text := _read_text(TUTORIAL_ENCOUNTER_PATH, failures)
	if text.is_empty():
		return

	_assert_step_override(text, "intro_draw_one", 1, failures)
	_assert_step_override(text, "teach_balance_action", 1, failures)
	_assert_step_override(text, "final_end_turn_unlock", 5, failures)


func _assert_step_override(text: String, step_id: String, expected: int, failures: Array[String]) -> void:
	var pattern := '(?s)id = &"%s".*?player_turn_draw_amount_override = %d' % [step_id, expected]
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		failures.append("tutorial encounter: failed to compile regex for %s" % step_id)
		return
	if regex.search(text) == null:
		failures.append(
			"tutorial encounter: expected %s to author player_turn_draw_amount_override = %d" % [
				step_id,
				expected,
			]
		)


func _read_text(resource_path: String, failures: Array[String]) -> String:
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		failures.append("verify: failed to open %s" % resource_path)
		return ""
	return file.get_as_text()
