extends CardAction

class_name GoodPosterityAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var mana_ctx := ManaContext.new()
	mana_ctx.source_id = int(ctx.source_id)
	mana_ctx.mode = ManaContext.Mode.GAIN_MANA
	mana_ctx.amount = 1
	mana_ctx.reason = "good_posterity"
	ctx.api.gain_mana(mana_ctx)

	return true

func get_description_value(_ctx: CardActionContext) -> String:
	return "1"
