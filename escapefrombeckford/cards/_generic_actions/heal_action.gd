# heal_action.gd

class_name HealAction extends CardAction

@export var flat_amount : int = 0
@export var of_total : float = 0.0
@export var of_missing : float = 0.0
@export var store_healed_amount_key: StringName = &""

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	if flat_amount < 0 or of_total < 0.0 or of_missing < 0.0:
		push_warning("heal_action.gd activate_sim(): negative heal input")
		return false

	var any_applied := false
	var any_target_processed := false
	if StringName(store_healed_amount_key) != &"":
		ctx.params[store_healed_amount_key] = 0

	for target_id in ctx.target_ids:
		var tid := int(target_id)
		if tid <= 0:
			continue
		any_target_processed = true

		var hctx := HealContext.new(
			int(ctx.source_id),
			tid,
			int(flat_amount),
			float(of_total),
			float(of_missing)
		)

		if ctx.card_data != null:
			hctx.tags.append(&"card")
			hctx.tags.append(StringName(ctx.card_data.name))

		var healed := ctx.api.heal(hctx)
		if StringName(store_healed_amount_key) != &"":
			ctx.params[store_healed_amount_key] = int(healed)
		if healed > 0:
			any_applied = true
			ctx.runtime.append_affected_id(ctx, tid)

	return any_applied or any_target_processed

func get_description_value(_ctx: CardActionContext) -> String:
	if int(flat_amount) != 0:
		return str(int(flat_amount))
	if !is_zero_approx(float(of_total)):
		return str(floori(float(of_total) * 100.0))
	if !is_zero_approx(float(of_missing)):
		return str(floori(float(of_missing) * 100.0))
	return ""
