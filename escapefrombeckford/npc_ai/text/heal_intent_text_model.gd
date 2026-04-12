# heal_intent_text_model.gd

class_name HealIntentTextModel extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"
	return "+%s" % get_preview_total_heal(ctx)

func get_preview_total_heal(ctx: NPCAIContext) -> int:
	var target_ids := _get_target_ids(ctx)
	if target_ids.is_empty():
		return maxi(_param_i(ctx, Keys.FLAT_AMOUNT, 0), 0)

	var total_heal := 0
	for tid in target_ids:
		total_heal += _get_preview_heal_for_target(ctx, int(tid))
	return maxi(total_heal, 0)

func _get_preview_heal_for_target(ctx: NPCAIContext, target_id: int) -> int:
	if ctx == null or target_id <= 0:
		return 0

	var flat_amount := maxi(_param_i(ctx, Keys.FLAT_AMOUNT, 0), 0)
	var of_total := maxf(float(_param_v(ctx, Keys.OF_TOTAL, 0.0)), 0.0)
	var of_missing := maxf(float(_param_v(ctx, Keys.OF_MISSING, 0.0)), 0.0)

	if ctx.api == null or ctx.api.state == null:
		return flat_amount

	var unit := ctx.api.state.get_unit(target_id)
	if unit == null:
		return flat_amount

	var max_health := maxi(int(unit.max_health), 0)
	if max_health <= 0:
		return 0

	var before_health := clampi(int(unit.health), 0, max_health)
	var working_health := clampi(before_health + flat_amount, 0, max_health)

	if of_total > 0.0:
		working_health = clampi(
			working_health + floori(float(max_health) * of_total),
			0,
			max_health
		)

	if of_missing > 0.0:
		working_health = clampi(
			working_health + floori(float(max_health - working_health) * of_missing),
			0,
			max_health
		)

	return maxi(working_health - before_health, 0)

func _get_target_ids(ctx: NPCAIContext) -> PackedInt32Array:
	var raw_target_ids = _param_v(ctx, Keys.TARGET_IDS, PackedInt32Array())
	if raw_target_ids is PackedInt32Array:
		return raw_target_ids
	if raw_target_ids is Array:
		return PackedInt32Array(raw_target_ids)
	return PackedInt32Array()
