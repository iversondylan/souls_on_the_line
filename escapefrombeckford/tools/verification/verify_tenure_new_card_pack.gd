extends SceneTree

var _failures: PackedStringArray = PackedStringArray()


func _init() -> void:
	_verify_soulbound_cards()
	_verify_axiomatic()
	_verify_heal_cards()
	_verify_sacrifice_cards()
	_verify_pools()
	if !_failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
	else:
		print("verify_tenure_new_card_pack: ok")
		quit()


func _verify_soulbound_cards() -> void:
	_expect_file_contains(
		"res://cards/souls/BrickGuardianCard/brick_guardian_card.tres",
		[
			"id = &\"brick_guardian\"",
			"name = \"Brick Guardian\"",
			"cost = 1",
			"summon_release_overload = 1",
			"brick-pile.png",
			"summon_brick_guardian.tres",
		]
	)
	_expect_file_contains(
		"res://cards/souls/BrickGuardianCard/summon_brick_guardian.tres",
		["reserves_card = true", "brick_guardian_data.tres"]
	)
	_expect_file_contains(
		"res://combatants/souls/BrickGuardian/brick_guardian_data.tres",
		["name = \"Brick Guardian\"", "max_health = 5", "ap = 4"]
	)
	_expect_file_contains(
		"res://combatants/souls/BrickGuardian/brick_guardian_attack_pkg.tres",
		["ap_damage_model.gd", "ranged_behind_player_model.gd"]
	)

	_expect_file_contains(
		"res://cards/souls/WoodstoveKeeperCard/woodstove_keeper_card.tres",
		[
			"id = &\"woodstove_keeper\"",
			"name = \"Woodstove Keeper\"",
			"cost = 1",
			"summon_release_overload = 1",
			"gas-stove.png",
			"summon_woodstove_keeper.tres",
		]
	)
	_expect_file_contains(
		"res://cards/souls/WoodstoveKeeperCard/summon_woodstove_keeper.tres",
		["reserves_card = true", "woodstove_keeper_data.tres"]
	)
	_expect_file_contains(
		"res://combatants/souls/WoodstoveKeeper/woodstove_keeper_data.tres",
		["name = \"Woodstove Keeper\"", "max_health = 4", "ap = 5"]
	)
	_expect_file_contains(
		"res://combatants/souls/WoodstoveKeeper/woodstove_keeper_attack_pkg.tres",
		["ap_damage_model.gd", "ranged_behind_player_model.gd"]
	)

	_expect_file_contains(
		"res://combatants/critters/Axiom/axiom_data.tres",
		["name = \"Axiom\"", "max_health = 3", "ap = 3"]
	)
	_expect_file_contains(
		"res://combatants/critters/Axiom/axiom_attack_pkg.tres",
		["ap_damage_model.gd", "ranged_behind_player_model.gd"]
	)


func _verify_axiomatic() -> void:
	_expect_file_contains(
		"res://statuses/axiomatic.tres",
		["status_name = \"Axiomatic\"", "auto_remove = 3", "gyroscope.png"]
	)
	_expect_file_contains(
		"res://statuses/axiomatic.gd",
		[
			"const ID := &\"axiomatic\"",
			"removal_ctx.removal_type",
			"Removal.Type.DEATH",
			"CombatantState.Mortality.WILD",
			"run_summon_action",
		]
	)
	_expect_file_contains(
		"res://cards/convocations/StateAxiom/state_axiom.tres",
		[
			"id = &\"state_axiom\"",
			"name = \"State Axiom\"",
			"cost = 1",
			"target_type = 3",
			"rarity = 1",
			"gyroscope.png",
		]
	)
	_expect_file_contains(
		"res://statuses/_core/status_catalog.tres",
		["res://statuses/axiomatic.tres", "ExtResource(\"67_axiomatic\")"]
	)


func _verify_heal_cards() -> void:
	_expect_file_contains(
		"res://cards/convocations/Invigorate/invigorate.tres",
		[
			"id = &\"invigorate\"",
			"name = \"Invigorate\"",
			"cost = 2",
			"target_type = 3",
			"rarity = 1",
			"heart-bottle.png",
		]
	)
	_expect_file_contains(
		"res://cards/convocations/Invigorate/invigorate_action.gd",
		[
			"0.0, 1.0",
			"healed / 3",
			"MIGHT.get_id()",
			"ctx.api.apply_status",
		]
	)
	_expect_file_contains(
		"res://cards/convocations/HearteningHeal/heartening_heal.tres",
		[
			"id = &\"heartening_heal\"",
			"name = \"Heartening Heal\"",
			"cost = 1",
			"defibrilate(1).png",
		]
	)
	_expect_file_contains(
		"res://cards/convocations/HearteningHeal/heartening_heal_action.gd",
		[
			"heal_amount: int = 5",
			"ENERGY_SURGE.get_id()",
			"status_ctx.stacks = healed",
			"DrawContext.new()",
		]
	)


func _verify_sacrifice_cards() -> void:
	_expect_file_contains(
		"res://cards/convocations/GoodPosterity/good_posterity.tres",
		[
			"id = &\"good_posterity\"",
			"name = \"Good Posterity\"",
			"sacrifice_action.tres",
			"good_posterity_action.tres",
			"draw_1_action.tres",
			"ExtResource(\"3_sacrifice\"), ExtResource(\"4_action\"), ExtResource(\"6_draw\")",
			"book-storm.png",
		]
	)
	_expect_file_contains(
		"res://cards/convocations/GoodPosterity/good_posterity_action.gd",
		["ManaContext.Mode.GAIN_MANA", "mana_ctx.amount = 1", "return \"1\""]
	)
	_expect_file_contains(
		"res://cards/convocations/MantleOfCare/mantle_of_care.tres",
		[
			"id = &\"mantle_of_care\"",
			"name = \"Mantle of Care\"",
			"cost = 1",
			"sacrifice_action.tres",
			"rod-of-asclepius.png",
		]
	)
	_expect_file_contains(
		"res://cards/convocations/MantleOfCare/mantle_of_care_action.gd",
		[
			"target_id == sacrificed_id",
			"PRESSURE_BARRIER.get_id()",
			"status_ctx.stacks = int(stacks)",
			"return true",
		]
	)


func _verify_pools() -> void:
	var card_paths := [
		"res://cards/souls/BrickGuardianCard/brick_guardian_card.tres",
		"res://cards/souls/WoodstoveKeeperCard/woodstove_keeper_card.tres",
		"res://cards/convocations/Invigorate/invigorate.tres",
		"res://cards/convocations/StateAxiom/state_axiom.tres",
		"res://cards/convocations/HearteningHeal/heartening_heal.tres",
		"res://cards/convocations/GoodPosterity/good_posterity.tres",
		"res://cards/convocations/MantleOfCare/mantle_of_care.tres",
	]
	_expect_file_contains("res://character_profiles/Cole/cole_draftable_cards.tres", card_paths)
	_expect_file_contains("res://character_profiles/Cole/one_of_each_card.tres", card_paths)


func _expect_file_contains(path: String, snippets: Array) -> void:
	var text := _read_text(path)
	if text.is_empty():
		_failures.append("Missing or empty file: %s" % path)
		return
	for snippet in snippets:
		if !text.contains(String(snippet)):
			_failures.append("%s missing snippet: %s" % [path, String(snippet)])


func _read_text(path: String) -> String:
	if !FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
