# intent_planner.gd

class_name IntentPlanner extends RefCounted

var dirty_ids: Dictionary = {} # int combat_id -> true
var dirty_all: bool = false

func mark_dirty(cid: int) -> void:
	if cid > 0:
		dirty_ids[int(cid)] = true

func mark_all_dirty() -> void:
	dirty_all = true

func clear_dirty() -> void:
	dirty_ids.clear()
	dirty_all = false

func ensure_valid_plan_for(api: SimBattleAPI, cid: int, allow_hooks: bool = true) -> void:
	if api == null or api.state == null:
		return
	if cid <= 0 or !api.is_alive(cid):
		return

	var u: CombatantState = api.state.get_unit(int(cid))
	if u == null or u.combatant_data == null or u.combatant_data.ai == null:
		return

	ActionPlanner._ensure_ai_state_initialized(u)

	var ctx := ActionPlanner._make_context(api, u)
	ActionPlanner.ensure_valid_plan_sim(u.combatant_data.ai, ctx, allow_hooks)

func ensure_valid_plans(api: SimBattleAPI, allow_hooks: bool = true) -> void:
	if api == null or api.state == null:
		return

	for cid in api.state.units.keys():
		ensure_valid_plan_for(api, int(cid), allow_hooks)

func flush(api: SimBattleAPI, allow_hooks: bool = true) -> void:
	print("intent_planner.gd flush() dirty_all=%s dirty_ids=%s" % [str(dirty_all), str(dirty_ids.keys())])
	if api == null or api.state == null:
		clear_dirty()
		return

	if dirty_all:
		ensure_valid_plans(api, allow_hooks)
		clear_dirty()
		return

	for cid in dirty_ids.keys():
		ensure_valid_plan_for(api, int(cid), allow_hooks)

	clear_dirty()

func run_npc_turn(api: SimBattleAPI, cid: int) -> void:
	ActionPlanner.run_turn(api, cid)
