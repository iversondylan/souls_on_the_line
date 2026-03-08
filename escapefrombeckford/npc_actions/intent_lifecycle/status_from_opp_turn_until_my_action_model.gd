# status_from_opp_turn_to_my_action_model.gd
class_name StatusFromOppTurnUntilMyActionModel
extends IntentLifecycleModel

@export var status: Status
@export var status_id: StringName
@export var intensity := 0
@export var duration := 0

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
	#print("status_from_opp_turn_until_my_action_model.gd _apply_to_self() id: %s, intensity: %s" % [status.get_id(), status.intensity])
	e.execute(api)

func _remove_from_self(ctx: NPCAIContext) -> void:
	var api := _resolve_api(ctx)
	if !api:
		return

	var e := RemoveStatusEffect.new()
	e.targets = [ctx.combatant]
	e.source = ctx.combatant
	e.status_id = _status_id()
	e.remove_all_intensity = true
	e.execute(api)

func on_opposing_group_start_sim(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_apply_to_self_sim(ctx)

func on_ability_started_sim(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)

func on_intent_canceled_sim(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)

func _can_run_sim(ctx: NPCAIContext) -> bool:
	if !ctx or bool(ctx.forecast):
		return false
	if !ctx.api:
		return false
	if !status:
		return false
	return ParamModel._actor_id(ctx) > 0

func _apply_to_self_sim(ctx: NPCAIContext) -> void:
	#var id := ParamModel._actor_id(ctx)
	if ctx.cid <= 0:
		return
	var sc := StatusContext.new()
	sc.source_id = ctx.cid
	sc.target_id = ctx.cid
	sc.status_id = status_id
	sc.duration = duration
	sc.intensity = intensity
	#print("status_from_opp_turn_until_my_action_model.gd _apply_to_self_sim() id: %s, intensity: %s" % [sc.status_id, sc.intensity])
	ctx.api.apply_status(sc)

func _remove_from_self_sim(ctx: NPCAIContext) -> void:
	var id := ParamModel._actor_id(ctx)
	if id <= 0:
		return
	var rc := RemoveStatusContext.new()
	rc.source_id = id
	rc.target_id = id
	rc.status_id = _status_id()
	rc.remove_all_intensity = true
	ctx.api.remove_status(rc)
