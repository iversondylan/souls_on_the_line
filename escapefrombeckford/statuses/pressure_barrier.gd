# pressure_barrier.gd

class_name PressureBarrier extends Status

const ID = &"pressure_barrier"

func get_id() -> StringName:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_TAKEN]

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if !ctx:
		return []

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_TAKEN
	token.flat_value = -ctx.intensity
	token.mult_value = 0.0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	return [token]

func on_damage_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or damage_ctx == null:
		return
	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return
	if damage_ctx.tags.has(&"self_recoil"):
		return

	var intensity := int(ctx.get_intensity())
	if intensity <= 1:
		ctx.remove_self("pressure_barrier_depleted")
	else:
		ctx.change_intensity(-1, "pressure_barrier_hit")

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Hits on this unit have their damage reduced by %s." % intensity
