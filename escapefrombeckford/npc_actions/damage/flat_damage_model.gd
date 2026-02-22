# flat_damage_model.gd
class_name FlatDamageModel extends ParamModel

@export var damage: int = 5


func change_params(ctx: NPCAIContext) -> NPCAIContext:
	# base damage only (no DMG_DEALT modifier here)
	ctx.params[NPCKeys.DAMAGE] = maxi(damage, 0)
	return ctx
