extends SceneTree

var _failures: PackedStringArray = PackedStringArray()


func _init() -> void:
	_verify_static_wiring()
	if !_failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
	else:
		print("verify_battle_card_visual_modifiers: ok")
		quit()


func _verify_static_wiring() -> void:
	_expect_file_contains(
		"res://cards/_core/card_visuals.gd",
		[
			"set_summon_card_stat_bonuses",
			"POSITIVE_STAT_MOD_COLOR",
			"NEGATIVE_STAT_MOD_COLOR",
			"_stat_modulate_for_delta(_summon_card_ap_bonus",
			"_stat_modulate_for_delta(_summon_card_max_health_bonus",
			"_format_attack_soul_stats(ctx, _summon_card_ap_bonus)",
			"_format_summon_soul_stats(ctx, summon_data, _summon_card_ap_bonus, _summon_card_max_health_bonus)",
		]
	)
	_expect_file_contains(
		"res://cards/_core/usable_card.gd",
		[
			"_apply_battle_summon_stat_bonuses()",
			"api.get_summon_card_ap_bonus(String(card_data.uid))",
			"api.get_summon_card_max_health_bonus(String(card_data.uid))",
			"_should_query_summon_stat_bonuses",
			"card_visuals.refresh_from_card_data()",
		]
	)
	_expect_file_contains(
		"res://cards/_core/menu_card.gd",
		[
			"refresh_battle_visuals",
			"!show_battle_modifications or api == null or !_should_query_summon_stat_bonuses()",
			"api.get_summon_card_ap_bonus(String(card_data.uid))",
			"api.get_summon_card_max_health_bonus(String(card_data.uid))",
		]
	)
	_expect_file_contains(
		"res://ui/card_pile_view.gd",
		[
			"card_tooltip_popup.api = api if show_battle_modifications else null",
			"card_tooltip_popup.show_battle_modifications = show_battle_modifications",
			"card.refresh_battle_visuals()",
		]
	)
	_expect_file_contains(
		"res://ui/card_tooltip_popup.gd",
		[
			"var api: SimBattleAPI",
			"var show_battle_modifications := false",
			"new_card.api = api",
			"new_card.show_battle_modifications = show_battle_modifications",
		]
	)


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
