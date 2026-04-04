# sim_merged_intensity_status_context.gd

class_name SimMergedIntensityStatusContext extends SimStatusContext

var owned_ctx: SimStatusContext = null
var aura_intensity_bonus: int = 0


func _init(_owned_ctx: SimStatusContext = null, _aura_intensity_bonus: int = 0) -> void:
	owned_ctx = _owned_ctx
	aura_intensity_bonus = int(_aura_intensity_bonus)

	if owned_ctx == null:
		return

	api = owned_ctx.api
	owner_id = int(owned_ctx.owner_id)
	owner = owned_ctx.owner
	stack = owned_ctx.stack
	proto = owned_ctx.proto


func is_valid() -> bool:
	return owned_ctx != null and owned_ctx.is_valid()


func get_intensity() -> int:
	if owned_ctx == null:
		return aura_intensity_bonus
	return int(owned_ctx.get_intensity()) + aura_intensity_bonus

