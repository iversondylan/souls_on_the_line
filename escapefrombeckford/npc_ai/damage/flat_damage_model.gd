# flat_damage_model.gd
class_name FlatDamageModel extends ParamModel

@export var damage: int = 5


func change_params(ctx: NPCAIContext) -> NPCAIContext:
	# base damage only (no DMG_DEALT modifier here)
	ctx.params[Keys.DAMAGE] = maxi(damage, 0)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	
	ctx.params[Keys.DAMAGE] = damage
	ctx.params[Keys.DAMAGE_MELEE] = damage
	ctx.params[Keys.DAMAGE_RANGED] = damage
	#print("flat_damage_model.gd total: ", total)
	return ctx
