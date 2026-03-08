# text_model.gd

class_name TextModel extends Resource

func get_text(_ctx: NPCAIContext) -> String:
	return ""

func get_text_sim(_ctx: NPCAIContext) -> String:
	return ""

# -------------------------
# Helpers for SIM models
# -------------------------

func _param_i(ctx: NPCAIContext, key, default_value: int = 0) -> int:
	if ctx == null or ctx.params == null:
		return default_value
	# Support keys stored as StringName or String
	if ctx.params.has(key):
		return int(ctx.params.get(key, default_value))
	var ksn := StringName(str(key))
	if ctx.params.has(ksn):
		return int(ctx.params.get(ksn, default_value))
	return default_value

func _param_v(ctx: NPCAIContext, key, default_value = null):
	if ctx == null or ctx.params == null:
		return default_value
	if ctx.params.has(key):
		return ctx.params.get(key, default_value)
	var ksn := StringName(str(key))
	if ctx.params.has(ksn):
		return ctx.params.get(ksn, default_value)
	return default_value

func _modified_sim(ctx: NPCAIContext, base_amount: int, modifier_type: int, source_id: int) -> int:
	if ctx == null or ctx.api == null:
		return base_amount
	if !(ctx.api is SimBattleAPI):
		return base_amount
	var api: SimBattleAPI = ctx.api
	if api.state == null:
		return base_amount
	return int(SimModifierResolver.get_modified_value(api.state, int(base_amount), int(modifier_type), int(source_id)))
