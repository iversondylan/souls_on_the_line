# stability_status.gd
class_name StabilityStatus extends Status

## Remaining stability is represented by intensity.
## When intensity reaches 0, stability is broken.

const ID := &"stability"

@export var max_stability: int = 10


func get_id() -> StringName:
	return ID


func affects_intent_legality() -> bool:
	return true


func get_tooltip_sim(ctx: SimStatusContext) -> String:
	if ctx == null or !ctx.is_valid():
		return "Stability"
	return "Stability: %s remaining. Breaking stability will interrupt this unit’s action." % ctx.get_intensity()


func on_damage_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or damage_ctx == null:
		return

	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return

	var hp_dmg := maxi(int(damage_ctx.health_damage), 0)
	if hp_dmg <= 0:
		return

	ctx.change_intensity(-hp_dmg, "damage_taken")

	if ctx.get_intensity() > 0:
		return

	ctx.ensure_ai_state()
	ctx.owner.ai_state[ActionPlanner.STABILITY_BROKEN] = true

	ctx.remove_self("stability_broken")
	ctx.request_replan()
	ctx.request_intent_refresh()
	ctx.api._request_immediate_planning_flush_if_needed(ctx.owner_id, self)
