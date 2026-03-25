# summon_action.gd
class_name SummonAction extends CardAction

@export var summon_data: CombatantData
@export var sound: Sound = load("res://audio/summon_zap.tres")

func get_interaction_mode(ctx: CardContext) -> int:
	if ctx == null or ctx.api == null:
		print("summon_action.gd get_interaction_mode() returning NONE")
		return InteractionMode.NONE
	
	var player_id := int(ctx.api.get_player_id())
	if player_id <= 0:
		print("summon_action.gd get_interaction_mode() returning NONE")
		return InteractionMode.NONE
	
	var soulbound_ids: Array[int] = ctx.api.get_soulbound_ids_for_owner(player_id)
	if soulbound_ids.size() >= UsableCard.MAX_SOULBOUND:
		print("summon_action.gd get_interaction_mode() returning ESCROW")
		return InteractionMode.ESCROW
	
	print("summon_action.gd get_interaction_mode() returning NONE")
	return InteractionMode.NONE


func activate_interaction(ctx: CardContext) -> bool:
	print("summon_action.gd activate_interaction()")
	if ctx == null or ctx.runtime == null or ctx.source_card == null:
		return false

	var action_index := int(ctx.current_action_index)
	if action_index < 0:
		action_index = int(ctx.escrow_action_index)

	var preview := SummonPreview.new()
	preview.summon_data = get_preview_summon_data()
	preview.insert_index = int(ctx.insert_index)

	if Events != null and Events.has_signal("request_summon_replace"):
		Events.request_summon_replace.emit(ctx, action_index, preview)
		return true

	return false


func activate_sim(ctx: CardContext) -> bool:
	print("summon_action.gd activate_sim()")
	if ctx == null or ctx.api == null or ctx.runtime == null:
		return false

	var insert_index := int(ctx.insert_index)
	if insert_index < 0:
		insert_index = 0

	var payload := ctx.runtime.get_action_interaction_payload(ctx, ctx.current_action_index)
	var replaced_id := int(payload.get(Keys.REPLACED_ID, 0))
	var replaced_insert_index := int(payload.get(Keys.REPLACED_INSERT_INDEX, -1))

	if replaced_id > 0:
		if replaced_insert_index >= 0 and replaced_insert_index < insert_index:
			insert_index -= 1

		ctx.runtime.run_fade(replaced_id, "summon_replace")

	var sctx := SummonContext.new()
	sctx.group_index = 0
	sctx.insert_index = insert_index
	sctx.source_id = int(ctx.source_id)
	sctx.summon_data = _build_clone_data_sim()
	sctx.mortality = CombatantView.Mortality.SOULBOUND

	if ctx.card_data != null and !ctx.card_data.deplete:
		ctx.card_data.ensure_uid()
		sctx.bound_card_uid = String(ctx.card_data.uid)

	if ctx.params != null and ctx.params.has(Keys.WINDUP_ORDER_IDS):
		var snap = ctx.params[Keys.WINDUP_ORDER_IDS]
		if snap is PackedInt32Array:
			sctx.windup_order_ids = snap

	ctx.api.summon(sctx)

	if sctx.summoned_id > 0:
		ctx.runtime.append_summoned_id(ctx, sctx.summoned_id)

	return true


func _build_clone_data_sim() -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	return data


func description_arity() -> int:
	return 3


func get_preview_summon_data() -> CombatantData:
	return summon_data


#func _build_clone_data(ctx: CardActionContext) -> CombatantData:
	#var data := summon_data.duplicate()
	#data.init()
	##
	#return data

#func get_description_values(ctx: CardActionContext) -> Array:
	#var data := summon_data.duplicate()
	#data.init()
	#var params := CombatForecast.preview_action_params(summon_data)
	#var dmg := int(params.get(Keys.DAMAGE, 0))
	#return [dmg, summon_data.max_health, summon_data.name]
