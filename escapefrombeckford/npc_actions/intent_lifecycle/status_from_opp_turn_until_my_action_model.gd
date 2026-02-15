# status_from_opp_turn_to_my_action_model.gd
class_name StatusFromOppTurnUntilMyActionModel
extends IntentLifecycleModel

@export var status: Status

func on_opposing_group_start(ctx: NPCAIContext) -> void:
	if !_can_run(ctx):
		return
	_apply_to_self(ctx)

func on_ability_started(ctx: NPCAIContext) -> void:
	if !_can_run(ctx):
		return
	_remove_from_self(ctx)

func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !_can_run(ctx):
		return
	_remove_from_self(ctx)

func _can_run(ctx: NPCAIContext) -> bool:
	if !ctx or bool(ctx.forecast):
		return false
	if !ctx.combatant or !is_instance_valid(ctx.combatant):
		return false
	if !status:
		return false
	return true

func _resolve_api(ctx: NPCAIContext) -> BattleAPI:
	var api: BattleAPI = ctx.api
	if !api and ctx.battle_scene:
		api = ctx.battle_scene.api
	return api

func _status_id() -> StringName:
	return StringName(status.get_id())

func _apply_to_self(ctx: NPCAIContext) -> void:
	var api := _resolve_api(ctx)
	if !api:
		return

	var e := StatusEffect.new()
	e.targets = [ctx.combatant]
	e.source = ctx.combatant
	e.status_id = _status_id()
	e.duration = status.duration
	e.intensity = status.intensity
	e.execute(api)

func _remove_from_self(ctx: NPCAIContext) -> void:
	var api := _resolve_api(ctx)
	if !api:
		return

	var e := RemoveStatusEffect.new()
	e.targets = [ctx.combatant]
	e.source = ctx.combatant
	e.status_id = _status_id()
	e.remove_all_stacks = true
	e.execute(api)
