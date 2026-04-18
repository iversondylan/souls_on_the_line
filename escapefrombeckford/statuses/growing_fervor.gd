class_name GrowingFervorStatus extends Status

const ID := &"growing_fervor"

const SHARED_FERVOR_STATUS := preload("uid://c851i8op6ei1")

func get_id() -> StringName:
	return ID


func on_actor_turn_begin(ctx: SimStatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or SHARED_FERVOR_STATUS == null:
		return

	var amount := maxi(int(ctx.get_intensity()), 0)
	if amount <= 0:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = SHARED_FERVOR_STATUS.get_id()
	status_ctx.intensity = amount
	status_ctx.reason = "growing_fervor"
	ctx.api.apply_status(status_ctx)

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Growing Fervor: at the start of this unit's turn, gain %s Shared Fervor." % intensity
