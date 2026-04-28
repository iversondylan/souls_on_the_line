# summon_action.gd
class_name SummonAction extends CardAction

@export var summon_data: CombatantData
@export var mortality: CombatantState.Mortality = CombatantState.Mortality.BOUND
@export var reserves_card: bool = false
@export var sound: Sound = load("uid://c0cllss7w30rn")

func get_preflight_interaction_mode(ctx: CardContext) -> int:
	if ctx == null or ctx.api == null:
		return InteractionMode.NONE

	var summon_mortality := _resolve_summon_mortality(ctx.card_data)
	if int(summon_mortality) != int(CombatantState.Mortality.BOUND):
		return InteractionMode.NONE
	
	var player_id := int(ctx.api.get_player_id())
	if player_id <= 0:
		return InteractionMode.NONE
	
	var bound_ids: Array[int] = ctx.api.get_bound_ids_for_owner(player_id)
	if bound_ids.size() >= CombatantState.get_mortality_cap(CombatantState.Mortality.BOUND):
		return InteractionMode.PREFLIGHT
	
	return InteractionMode.NONE

func begin_preflight_interaction(ctx: CardContext) -> bool:
	if ctx == null or ctx.runtime == null or ctx.source_card == null:
		return false

	var action_index := int(ctx.current_action_index)
	if action_index < 0:
		return false

	var preview := SummonPreview.new()
	preview.summon_data = get_preview_summon_data()
	preview.insert_index = int(ctx.insert_index)

	if Events != null and Events.has_signal("request_interaction"):
		var interaction := SummonReplaceInteractionContext.new()
		interaction.card_ctx = ctx
		interaction.action_index = action_index
		interaction.preview = preview
		Events.request_interaction.emit(interaction)
		return true

	return false


func activate_sim(ctx: CardContext) -> bool:
	#print("summon_action.gd activate_sim()")
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

		var removal_ctx = RemovalContext.new()
		removal_ctx.target_id = replaced_id
		removal_ctx.removal_type = Removal.Type.FADE
		removal_ctx.reason = "summon_replace"
		if ctx.card_data != null:
			ctx.card_data.ensure_uid()
			removal_ctx.origin_card_uid = String(ctx.card_data.uid)
		ctx.runtime.run_removal(removal_ctx)

	var sctx := SummonContext.new()
	sctx.actor_id = int(ctx.source_id)
	sctx.group_index = 0
	sctx.insert_index = insert_index
	sctx.source_id = int(ctx.source_id)
	sctx.summon_data = _build_clone_data_sim()
	sctx.mortality = _resolve_summon_mortality(ctx.card_data)
	sctx.reason = "card_summon"
	sctx.sfx = sound

	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		sctx.origin_card_uid = String(ctx.card_data.uid)
		sctx.origin_card_type = int(ctx.card_data.card_type)
		var player_id := int(ctx.api.get_player_id())
		sctx.eligible_player_soul_summon = (
			int(ctx.source_id) == player_id
			and (
				int(ctx.card_data.card_type) == int(CardData.CardType.SOULBOUND)
				or int(ctx.card_data.card_type) == int(CardData.CardType.SOULWILD)
			)
		)
	var should_reserve := reserves_card \
		and ctx.card_data != null \
		and !ctx.card_data.deplete \
		and !ctx.reserve_claimed
	if should_reserve:
		sctx.bound_card_uid = String(ctx.card_data.uid)

	if ctx.params != null and ctx.params.has(Keys.WINDUP_ORDER_IDS):
		var snap = ctx.params[Keys.WINDUP_ORDER_IDS]
		if snap is PackedInt32Array:
			sctx.windup_order_ids = snap

	ctx.runtime.run_summon_action(sctx)

	if sctx.summoned_id > 0:
		ctx.runtime.append_summoned_id(ctx, sctx.summoned_id)
		if should_reserve:
			ctx.reserve_claimed = true
			ctx.reserved_card_uid = String(sctx.bound_card_uid)
			ctx.reserved_summoned_id = int(sctx.summoned_id)

	return true


func _resolve_summon_mortality(card_data: CardData) -> CombatantState.Mortality:
	if card_data == null:
		return mortality
	match int(card_data.card_type):
		int(CardData.CardType.SOULBOUND):
			return CombatantState.Mortality.BOUND
		int(CardData.CardType.SOULWILD):
			return CombatantState.Mortality.WILD
		_:
			return mortality


func _build_clone_data_sim() -> CombatantData:
	var data := summon_data.duplicate()
	return data

func get_preview_summon_data() -> CombatantData:
	return summon_data

func get_description_value(_ctx: CardActionContext) -> String:
	if summon_data == null:
		return ""

	var text := summon_data.get_description().strip_edges()
	if text.is_empty():
		return ""
	return text + " "
