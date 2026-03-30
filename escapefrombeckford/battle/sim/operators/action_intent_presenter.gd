# action_intent_presenter.gd

class_name ActionIntentPresenter extends RefCounted

static func emit_set_intent(api: SimBattleAPI, profile: NPCAIProfile, ctx: NPCAIContext, new_idx: int) -> void:
	if api == null or api.writer == null or profile == null or ctx == null:
		return

	var actor_id := int(ctx.cid)

	if new_idx < 0:
		api.writer.emit_set_intent(actor_id, -1, "", "", "", "", false)
		return

	var action := ActionPlanner.get_action_by_idx(profile, new_idx)
	if action == null:
		api.writer.emit_set_intent(actor_id, -1, "", "", "", "", false)
		return

	_change_params_only(action, ctx)

	var is_ranged := false
	if ctx.params != null and ctx.params.has(Keys.ATTACK_MODE):
		is_ranged = int(ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE)) == Attack.Mode.RANGED

	var uid := String(action.intent_icon_uid)
	var uid_ranged := String(action.intent_icon_ranged_uid)

	var intent_text := ""
	var tooltip_text := ""

	if action.intent_text_model:
		intent_text = String(action.intent_text_model.get_text(ctx))

	if action.tooltip_model:
		tooltip_text = String(action.tooltip_model.get_text(ctx))

	api.writer.emit_set_intent(actor_id, new_idx, uid, uid_ranged, intent_text, tooltip_text, is_ranged)

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
		api.writer.emit_set_intent(int(cid), -1, "", "", "", "", false)
		return

	ActionPlanner.ensure_ai_state_initialized(u)

	var idx := int(u.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	var ctx := ActionPlanner.make_context(api, u)

	if idx < 0:
		api.writer.emit_set_intent(int(cid), -1, "", "", "", "", false)
		return

	var action := ActionPlanner.get_action_by_idx(profile, idx)
	if action == null:
		api.writer.emit_set_intent(int(cid), -1, "", "", "", "", false)
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

	if action.intent_text_model:
		intent_text = String(action.intent_text_model.get_text(ctx))

	if action.tooltip_model:
		tooltip_text = String(action.tooltip_model.get_text(ctx))

	api.writer.emit_set_intent(int(cid), idx, uid, uid_ranged, intent_text, tooltip_text, is_ranged)

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
