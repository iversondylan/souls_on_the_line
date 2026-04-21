extends SceneTree

const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const ProjectedStatusContributionIndex := preload("res://battle/sim/containers/projected_status_contribution_index.gd")
const SimBattleAPI := preload("res://battle/sim/operators/sim_battle_api.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")
const StatusContext := preload("res://battle/contexts/status_context.gd")
const StatusState := preload("res://battle/sim/containers/status_state.gd")
const StatusToken := preload("res://battle/sim/containers/status_token.gd")

func _init() -> void:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()
	_verify_owned_reapply(status_catalog)
	_verify_projected_merging(status_catalog)
	print("verify_reapply_type: ok")
	quit()

func _verify_owned_reapply(status_catalog: StatusCatalog) -> void:
	_assert_owned_reapply(status_catalog, &"marked", 2, 3, 5)
	_assert_owned_reapply(status_catalog, &"stability", 4, 1, 1)
	_assert_owned_reapply(status_catalog, &"yggdrasil_guard", 5, 2, 5)
	_assert_owned_reapply(status_catalog, &"danger_zone", 1, 1, 1)

func _verify_projected_merging(status_catalog: StatusCatalog) -> void:
	_assert_projected_merge(status_catalog, &"marked", 2, 5, 7)
	_assert_projected_merge(status_catalog, &"stability", 4, 9, 9)
	_assert_projected_merge(status_catalog, &"yggdrasil_guard", 3, 8, 3)
	_assert_projected_merge(status_catalog, &"danger_zone", 1, 1, 1)

func _assert_owned_reapply(
	status_catalog: StatusCatalog,
	status_id: StringName,
	first_stacks: int,
	second_stacks: int,
	expected_stacks: int
) -> void:
	var setup := _make_api_and_unit(status_catalog)
	var api := setup.get("api", null) as SimBattleAPI
	var unit := setup.get("unit", null) as CombatantState
	_apply_status(api, int(unit.id), status_id, first_stacks)
	_apply_status(api, int(unit.id), status_id, second_stacks)
	assert(
		_get_realized_stacks(unit, status_id) == expected_stacks,
		"owned reapply mismatch for %s" % String(status_id)
	)

func _assert_projected_merge(
	status_catalog: StatusCatalog,
	status_id: StringName,
	first_stacks: int,
	second_stacks: int,
	expected_stacks: int
) -> void:
	var proto := status_catalog.get_proto(status_id)
	assert(proto != null, "missing status proto %s" % String(status_id))

	var state := StatusState.new()
	state.upsert_projected_source(
		"older",
		[_make_projected_token(status_id, first_stacks)],
		{"priority": 1, "tid": 1}
	)
	state.upsert_projected_source(
		"newer",
		[_make_projected_token(status_id, second_stacks)],
		{"priority": 1, "tid": 2}
	)
	state.rebuild_projected_tokens(func(requested_status_id: StringName):
		return status_catalog.get_proto(requested_status_id)
	)

	var projected := state.get_projected_status_token(status_id)
	assert(projected != null, "missing projected token for %s" % String(status_id))
	assert(
		int(projected.stacks) == expected_stacks,
		"projected merge mismatch for %s" % String(status_id)
	)

	var direct_index := ProjectedStatusContributionIndex.new()
	direct_index.replace_source(
		"older",
		[_make_projected_token(status_id, first_stacks)],
		{"priority": 1, "tid": 1}
	)
	direct_index.replace_source(
		"newer",
		[_make_projected_token(status_id, second_stacks)],
		{"priority": 1, "tid": 2}
	)
	var direct_projected := direct_index.build_projected_token(status_id, proto)
	assert(direct_projected != null, "missing direct projected token for %s" % String(status_id))
	assert(
		int(direct_projected.stacks) == expected_stacks,
		"direct projected merge mismatch for %s" % String(status_id)
	)

func _make_api_and_unit(status_catalog: StatusCatalog) -> Dictionary:
	var state := BattleState.new()
	state.init(11, 17)
	state.status_catalog = status_catalog

	var unit := CombatantState.new()
	unit.id = state.alloc_id()
	unit.team = BattleState.FRIENDLY
	unit.type = CombatantView.Type.ALLY
	unit.name = "Verifier"
	unit.max_health = 20
	unit.health = 20
	unit.alive = true
	state.add_unit(unit, BattleState.FRIENDLY)

	return {
		"api": SimBattleAPI.new(state),
		"unit": unit,
	}

func _apply_status(api: SimBattleAPI, target_id: int, status_id: StringName, stacks: int) -> void:
	var ctx := StatusContext.new()
	ctx.source_id = target_id
	ctx.target_id = target_id
	ctx.status_id = status_id
	ctx.stacks = stacks
	api.apply_status(ctx)

func _get_realized_stacks(unit: CombatantState, status_id: StringName) -> int:
	var token := unit.statuses.get_status_token(status_id, false)
	return int(token.stacks) if token != null else 0

func _make_projected_token(status_id: StringName, stacks: int) -> StatusToken:
	var token := StatusToken.new(status_id)
	token.pending = false
	token.stacks = stacks
	return token
