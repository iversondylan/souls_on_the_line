class_name YggdrasilGuardStatus extends Status

const ID := &"yggdrasil_guard"
const EMPTY_FORTITUDE := preload("res://statuses/empty_fortitude.tres")
const CONSUMED_EVENT_KEY := &"yggdrasil_guard_consumed"

func get_id() -> StringName:
	return ID

func on_damage_will_be_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or damage_ctx == null:
		return
	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return
	if !_is_eligible_strike_damage(damage_ctx):
		return

	var amount := maxi(int(ctx.get_intensity()), 0)
	if amount <= 0:
		return

	damage_ctx.amount = maxi(int(damage_ctx.amount) - amount, 0)
	if damage_ctx.event_extra == null:
		damage_ctx.event_extra = {}
	damage_ctx.event_extra[CONSUMED_EVENT_KEY] = true

func on_damage_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or damage_ctx == null:
		return
	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return
	if !bool(damage_ctx.event_extra.get(CONSUMED_EVENT_KEY, false)):
		return
	if ctx.owner == null or !ctx.owner.is_alive():
		return

	ctx.remove_self("yggdrasil_guard_spent")

func on_remove(ctx: SimStatusContext, _remove_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or EMPTY_FORTITUDE == null:
		return
	if ctx.owner == null or !ctx.owner.is_alive():
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = EMPTY_FORTITUDE.get_id()
	status_ctx.intensity = 2
	status_ctx.reason = "yggdrasil_guard"
	ctx.api.apply_status(status_ctx)

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Yggdrasil Guard: the first strike each round against this unit is reduced by %s. If it survives, gain +2 empty max health." % intensity

func _is_eligible_strike_damage(damage_ctx: DamageContext) -> bool:
	if damage_ctx == null:
		return false
	if int(damage_ctx.amount) <= 0:
		return false
	if !damage_ctx.tags.has(&"strike_damage"):
		return false
	if damage_ctx.tags.has(&"self_recoil"):
		return false
	return true
