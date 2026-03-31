# action_intent_presenter.gd

class_name ActionIntentPresenter extends RefCounted

const BANISH_INTENT_TEXT_COLOR := Color(0.45, 0.75, 1.0, 1.0)

static func emit_set_intent(api: SimBattleAPI, profile: NPCAIProfile, ctx: NPCAIContext, new_idx: int) -> void:
	if api == null or api.writer == null or profile == null or ctx == null:
		return

	var actor_id := int(ctx.cid)
	var intent_text_color := Color.WHITE

	if new_idx < 0:
		api.writer.emit_set_intent(actor_id, -1, "", "", "", "", false, intent_text_color)
		return

	var action := ActionPlanner.get_action_by_idx(profile, new_idx)
	if action == null:
		api.writer.emit_set_intent(actor_id, -1, "", "", "", "", false, intent_text_color)
		return

	_change_params_only(action, ctx)

	var is_ranged := false
	if ctx.params != null and ctx.params.has(Keys.ATTACK_MODE):
		is_ranged = int(ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE)) == Attack.Mode.RANGED

	var uid := String(action.intent_icon_uid)
	var uid_ranged := String(action.intent_icon_ranged_uid)

	var intent_text := ""
	var tooltip_text := ""
	var preview_package_index := _find_attack_preview_package_index(action)
	ctx.preview_package_index = preview_package_index
	intent_text_color = _resolve_intent_text_color(ctx, actor_id)

	if action.intent_text_model:
		intent_text = String(action.intent_text_model.get_text(ctx))

	if action.tooltip_model:
		tooltip_text = String(action.tooltip_model.get_text(ctx))

	api.writer.emit_set_intent(actor_id, new_idx, uid, uid_ranged, intent_text, tooltip_text, is_ranged, intent_text_color)

	ctx.preview_package_index = -1
	if ctx.params != null:
		ctx.params.clear()


static func emit_current_intent(api: SimBattleAPI, cid: int) -> void:
	if api == null or api.state == null or api.writer == null:
		return

	var u: CombatantState = api.state.get_unit(int(cid))
	if u == null or !u.is_alive() or u.combatant_data == null:
		return

	var profile: NPCAIProfile = u.combatant_data.ai
	if profile == null:
		api.writer.emit_set_intent(int(cid), -1, "", "", "", "", false, Color.WHITE)
		return

	ActionPlanner.ensure_ai_state_initialized(u)

	var idx := int(u.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	var ctx := ActionPlanner.make_context(api, u)

	if idx < 0:
		api.writer.emit_set_intent(int(cid), -1, "", "", "", "", false, Color.WHITE)
		return

	var action := ActionPlanner.get_action_by_idx(profile, idx)
	if action == null:
		api.writer.emit_set_intent(int(cid), -1, "", "", "", "", false, Color.WHITE)
		return

	if ctx.params == null:
		ctx.params = {}
	else:
		ctx.params.clear()

	for pkg in action.effect_packages:
		if pkg == null:
			continue
		for pm: ParamModel in pkg.param_models:
			if pm != null:
				pm.change_params_sim(ctx)

	var is_ranged := int(ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE)) == Attack.Mode.RANGED
	var uid := String(action.intent_icon_uid)
	var uid_ranged := String(action.intent_icon_ranged_uid)

	var intent_text := ""
	var tooltip_text := ""
	var preview_package_index := _find_attack_preview_package_index(action)
	ctx.preview_package_index = preview_package_index
	var intent_text_color := _resolve_intent_text_color(ctx, int(cid))

	if action.intent_text_model:
		intent_text = String(action.intent_text_model.get_text(ctx))

	if action.tooltip_model:
		tooltip_text = String(action.tooltip_model.get_text(ctx))

	api.writer.emit_set_intent(int(cid), idx, uid, uid_ranged, intent_text, tooltip_text, is_ranged, intent_text_color)

	ctx.preview_package_index = -1
	if ctx.params != null:
		ctx.params.clear()


static func _change_params_only(action: NPCAction, ctx: NPCAIContext) -> void:
	if action == null or ctx == null:
		return

	if ctx.params == null:
		ctx.params = {}
	else:
		ctx.params.clear()

	for pkg: NPCEffectPackage in action.effect_packages:
		if pkg == null:
			continue
		for model: ParamModel in pkg.param_models:
			if model == null:
				continue
			model.change_params_sim(ctx)

static func _resolve_intent_text_color(ctx: NPCAIContext, actor_id: int) -> Color:
	if ctx == null or int(ctx.preview_package_index) < 0:
		return Color.WHITE
	var base_damage := 0
	if ctx.params != null:
		base_damage = int(ctx.params.get(Keys.DAMAGE, 0))
	var base_banish_damage := 0
	if ctx.params != null:
		base_banish_damage = int(ctx.params.get(Keys.BANISH_DAMAGE, 0))
	var components := PendingIntentModifierResolver.get_attack_display_components(
		ctx,
		base_damage,
		base_banish_damage,
		actor_id
	)
	if int(components.get("banish_damage", 0)) > 0:
		return BANISH_INTENT_TEXT_COLOR
	return Color.WHITE

static func _find_attack_preview_package_index(action: NPCAction) -> int:
	if action == null:
		return -1

	for i in range(action.effect_packages.size()):
		var pkg: NPCEffectPackage = action.effect_packages[i]
		if pkg == null or pkg.effect == null:
			continue
		if pkg.effect is NPCAttackSequence:
			return i

	return -1
