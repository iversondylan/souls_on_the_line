# sim_merged_intensity_status_context.gd

class_name SimMergedIntensityStatusContext extends SimStatusContext

var owned_ctx: SimStatusContext = null
var projected_intensity_bonus: int = 0


func _init(_owned_ctx: SimStatusContext = null, _projected_intensity_bonus: int = 0) -> void:
	owned_ctx = _owned_ctx
	projected_intensity_bonus = int(_projected_intensity_bonus)

	if owned_ctx == null:
		return

	api = owned_ctx.api
	owner_id = int(owned_ctx.owner_id)
	owner = owned_ctx.owner
	token = owned_ctx.token
	proto = owned_ctx.proto


func is_valid() -> bool:
	return owned_ctx != null and owned_ctx.is_valid()


func get_intensity() -> int:
	if owned_ctx == null:
		return projected_intensity_bonus
	return int(owned_ctx.get_intensity()) + projected_intensity_bonus
