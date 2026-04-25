extends SceneTree

const CardAction := preload("res://cards/_core/card_action.gd")
const CardData := preload("res://cards/_core/card_data.gd")
const DrawAction := preload("res://cards/_generic_actions/draw_action.gd")
const TextUtils := preload("res://core/utils/TextUtils.gd")

const AXOLOTL_ASCETIC := preload("res://cards/souls/AxolotlAsceticCard/axolotl_ascetic_card.tres")
const CRONE_PUPPETEER := preload("res://cards/souls/CronePuppeteerCard/crone_puppeteer_card.tres")
const CRYSTAL_BARRIER := preload("res://cards/convocations/CrystalBarrier/crystal_barrier.tres")
const FORMIC_DRONE := preload("res://cards/souls/FormicDrone/formic_drone.tres")
const GLASS_PECCARY := preload("res://cards/souls/GlassPeccaryCard/glass_peccary_card.tres")
const SCARAB_SUBSTITUTION := preload("res://cards/convocations/ScarabSubstitution/scarab_substitution.tres")
const TEMPERED_SILVERBACK := preload("res://cards/souls/TemperedSilverbackCard/tempered_silverback_card.tres")


func _init() -> void:
	_verify_leftover_placeholders_stay_visible()
	_verify_extra_actions_append_suffix()
	_verify_glass_peccary_renders_new_style()
	_verify_formic_drone_renders_status_label_with_plain_english()
	_verify_tempered_silverback_renders_plain_english()
	_verify_axolotl_ascetic_renders_status_label_with_plain_english()
	_verify_crone_uses_only_its_own_combatant_description()
	_verify_scarab_substitution_renders_non_soul_summon_cleanly()
	_verify_crystal_barrier_renders_plain_english_status_text()
	_verify_all_card_templates_match_action_count()
	_verify_all_rendered_card_descriptions_are_clean()
	_verify_soul_summon_descriptions_avoid_statlines()
	_verify_exported_card_strings_avoid_legacy_phrasing()
	_verify_battle_and_menu_paths_match()
	print("verify_card_description_formatting: ok")
	quit()


func _verify_leftover_placeholders_stay_visible() -> void:
	var card := CardData.new()
	card.name = "Placeholder Check"
	card.description = "%s then %s"
	card.actions = [_make_draw_action(2)]

	var rendered := TextUtils.build_card_description(card)
	assert(rendered == "2 then %s", "Unused placeholders should remain visible.")


func _verify_extra_actions_append_suffix() -> void:
	var card := CardData.new()
	card.name = "Overflow Check"
	card.description = "%s"
	card.actions = [_make_draw_action(1), _make_draw_action(2)]

	var rendered := TextUtils.build_card_description(card)
	assert(rendered == "1%s" % CardAction.EXTRA_CARD_ACTION_TEXT, "Extra actions should append the overflow marker.")


func _verify_glass_peccary_renders_new_style() -> void:
	var rendered := TextUtils.build_card_description(GLASS_PECCARY)
	assert(
		rendered == "A fragile soul that leaves a parting gift. On Death, draw 1 and deal 3 damage.",
		"Glass Peccary should render its summon flavor plus its two numeric death riders."
	)


func _verify_formic_drone_renders_status_label_with_plain_english() -> void:
	var rendered := TextUtils.build_card_description(FORMIC_DRONE)
	assert(
		rendered == "Protected Drone: On Death, summon a Small, Wild Fire Ant that damages enemies on death.",
		"Formic Drone should keep the non-numerical status label and explain its effect in plain English."
	)


func _verify_tempered_silverback_renders_plain_english() -> void:
	var rendered := TextUtils.build_card_description(TEMPERED_SILVERBACK)
	assert(
		rendered == "When hit, gain 2 max health. This persists on-card for the battle.",
		"Tempered Silverback should no longer render a statline or a status-name template."
	)


func _verify_axolotl_ascetic_renders_status_label_with_plain_english() -> void:
	var rendered := TextUtils.build_card_description(AXOLOTL_ASCETIC)
	assert(
		rendered == "Ascetic Threshold: the first time each round damage leaves this below half health, negate the next hit and increase max health by 2 and heal that amount.",
		"Axolotl Ascetic should keep the status label and explain the effect in plain English."
	)


func _verify_crone_uses_only_its_own_combatant_description() -> void:
	var rendered := TextUtils.build_card_description(CRONE_PUPPETEER)
	assert(
		rendered == "Does not attack. Summons a Patchwork Puppet at the front.",
		"Crone Puppeteer should render only from its own combatant description."
	)


func _verify_scarab_substitution_renders_non_soul_summon_cleanly() -> void:
	var rendered := TextUtils.build_card_description(SCARAB_SUBSTITUTION)
	assert(
		rendered == "Sacrifice an ally. Summon a defensive Shield Mite at the front. Hits on it deal 1 less damage, decreasing each time, until your next turn. Absorb: negate the next hit.",
		"Scarab Substitution should use behavior-only summon text and render all four actions cleanly."
	)


func _verify_crystal_barrier_renders_plain_english_status_text() -> void:
	var rendered := TextUtils.build_card_description(CRYSTAL_BARRIER)
	assert(
		rendered == "Hits on an ally deal 3 less damage, decreasing each time. Absorb: negate the next hit.",
		"Crystal Barrier should explain both granted effects without leftover formatter markers."
	)


func _verify_all_card_templates_match_action_count() -> void:
	for card in _load_all_cards():
		assert(
			card.description.count("%s") == card.actions.size(),
			"%s should have one placeholder per action." % String(card.resource_path)
		)


func _verify_all_rendered_card_descriptions_are_clean() -> void:
	for card in _load_all_cards():
		var rendered := TextUtils.build_card_description(card)
		assert(!rendered.contains("%s"), "%s should not leave literal placeholders after rendering." % String(card.resource_path))
		assert(
			!rendered.contains(CardAction.EXTRA_CARD_ACTION_TEXT),
			"%s should not append the extra action marker after the export cleanup." % String(card.resource_path)
		)


func _verify_soul_summon_descriptions_avoid_statlines() -> void:
	var statline_regex := RegEx.new()
	assert(statline_regex.compile("\\b\\d+/\\d+\\b") == OK, "Statline regex should compile.")

	for card in _load_all_cards_in_dir("res://cards/souls"):
		if card.actions.is_empty():
			continue

		var summon_data = _get_object_property(card.actions[0], "summon_data")
		if summon_data == null:
			continue

		var summon_description := String(summon_data.get_description()).strip_edges()
		assert(
			statline_regex.search(summon_description) == null,
			"%s should not rely on a statline-style summon description." % String(card.resource_path)
		)


func _verify_exported_card_strings_avoid_legacy_phrasing() -> void:
	for card in _load_all_cards():
		var text := String(card.description)
		assert(!text.contains("It has %s"), "%s should not use the old 'It has %%s' phrasing." % String(card.resource_path))
		assert(!text.contains("It has Tempered %s"), "%s should not use the old Tempered template." % String(card.resource_path))
		assert(!text.contains("%s/%s %s"), "%s should not use the legacy summon stat formatter." % String(card.resource_path))


func _verify_battle_and_menu_paths_match() -> void:
	var menu_text := TextUtils.build_card_description(GLASS_PECCARY)
	var battle_text := TextUtils.build_battle_card_description(GLASS_PECCARY, null)
	assert(menu_text == battle_text, "Battle and menu description builders should render the same text.")


func _load_all_cards() -> Array[CardData]:
	return _load_all_cards_in_dir("res://cards")


func _load_all_cards_in_dir(dir_path: String) -> Array[CardData]:
	var found: Array[CardData] = []
	_load_all_cards_recursive(dir_path, found)
	return found


func _load_all_cards_recursive(dir_path: String, found: Array[CardData]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	for subdir in dir.get_directories():
		_load_all_cards_recursive("%s/%s" % [dir_path, subdir], found)

	for file_name in dir.get_files():
		if !file_name.ends_with(".tres"):
			continue
		var path := "%s/%s" % [dir_path, file_name]
		var resource := load(path)
		if resource is CardData:
			found.append(resource as CardData)


func _get_object_property(obj: Object, property_name: String):
	if obj == null:
		return null
	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == property_name:
			return obj.get(property_name)
	return null


func _make_draw_action(amount: int) -> DrawAction:
	var action := DrawAction.new()
	action.base_draw = amount
	return action
