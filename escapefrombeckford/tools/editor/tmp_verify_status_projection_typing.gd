extends SceneTree

const EffectiveStatusContextCacheStore := preload("res://battle/sim/containers/effective_status_context_cache_store.gd")
const ProjectionImpactInfo := preload("res://battle/sim/containers/projection_impact_info.gd")
const ProjectionSourceEntry := preload("res://battle/sim/containers/projection_source_entry.gd")
const ProjectionBank := preload("res://battle/sim/containers/projection_bank.gd")
const SimBattleAPI := preload("res://battle/sim/operators/sim_battle_api.gd")
const PendingIntentModifierResolver := preload("res://battle/sim/operators/pending_intent_modifier_resolver.gd")
const SimStatusContext := preload("res://battle/sim/containers/sim_status_context.gd")
const SimStatusSystem := preload("res://battle/sim/operators/sim_status_system.gd")
const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantData := preload("res://combatants/combatant_data.gd")
const NPCAIContext := preload("res://npc_ai/_core/npc_ai_context.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusState := preload("res://battle/sim/containers/status_state.gd")
const StatusContext := preload("res://battle/contexts/status_context.gd")
const StatusToken := preload("res://battle/sim/containers/status_token.gd")


func _initialize() -> void:
	var failures: Array[String] = []

	_verify_projection_impact_info_merge(failures)
	_verify_effective_status_context_cache_store(failures)
	_verify_projection_bank_entries(failures)
	_verify_status_state_projection_aggregation(failures)
	_verify_status_state_pending_realization(failures)
	_verify_pending_and_realized_aura_projection_merge(failures)
	_verify_pending_modifier_preview(failures)
	_verify_pending_duration_and_group_expiration(failures)
	_verify_realization_does_not_reapply_pending_on_apply_hooks(failures)

	if failures.is_empty():
		print("STATUS PROJECTION TYPING VERIFY OK")
		quit()
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _verify_projection_impact_info_merge(failures: Array[String]) -> void:
	var left: ProjectionImpactInfo = ProjectionImpactInfo.new(true, PackedInt32Array([2, 4]))
	var right: ProjectionImpactInfo = ProjectionImpactInfo.new(false, PackedInt32Array([4, 5]))
	var merged: ProjectionImpactInfo = left.merged_with(right)

	if !merged.known:
		failures.append("projection_impact_info: merged known flag should stay true")
	if merged.target_ids != PackedInt32Array([2, 4, 5]):
		failures.append("projection_impact_info: merged target ids were %s" % [str(merged.target_ids)])


func _verify_effective_status_context_cache_store(failures: Array[String]) -> void:
	var store := EffectiveStatusContextCacheStore.new()
	var empty_contexts: Array[SimStatusContext] = []
	store.set_contexts(3, 7, empty_contexts)

	if !store.has_contexts(3, 7):
		failures.append("effective_status_context_cache_store: expected cached empty array to count as a hit")

	store.invalidate()
	if store.has_contexts(3, 7):
		failures.append("effective_status_context_cache_store: invalidate should clear cached entries")


func _verify_projection_bank_entries(failures: Array[String]) -> void:
	var bank := ProjectionBank.new()
	if !bank.track_status_aura(8, &"alpha"):
		failures.append("projection_bank: expected initial aura track to change the bank")
	if bank.track_status_aura(8, &"alpha"):
		failures.append("projection_bank: same aura source should not duplicate by pending lane anymore")
	bank.track_status_aura(3, &"beta")

	var entries: Array[ProjectionSourceEntry] = bank.get_entries()
	if entries.size() != 2:
		failures.append("projection_bank: expected 2 typed entries, got %d" % entries.size())
		return
	if !(entries[0] is ProjectionSourceEntry) or !(entries[1] is ProjectionSourceEntry):
		failures.append("projection_bank: expected ProjectionSourceEntry results from get_entries()")
	if entries[0].get_source_key() != ProjectionSourceEntry.make_source_key(entries[0].source_kind, entries[0].source_owner_id, entries[0].source_id):
		failures.append("projection_bank: source key helper mismatch")


func _verify_status_state_projection_aggregation(failures: Array[String]) -> void:
	var status_state := StatusState.new()
	var projected_a := StatusToken.new(&"marked")
	projected_a.intensity = 2
	projected_a.duration = 3
	var projected_b := StatusToken.new(&"marked")
	projected_b.intensity = 1
	projected_b.duration = 5

	var version_before := status_state.get_effective_context_version()
	var source_a_tokens: Array[StatusToken] = [projected_a]
	var source_b_tokens: Array[StatusToken] = [projected_b]
	status_state.upsert_projected_source("src_a", source_a_tokens)
	status_state.upsert_projected_source("src_b", source_b_tokens)
	var combined: StatusToken = status_state.get_projected_status_token(&"marked")
	if combined == null:
		failures.append("status_state: expected projected marked token after two sources")
		return
	if int(combined.intensity) != 3 or int(combined.duration) != 5:
		failures.append("status_state: projected aggregation expected intensity=3 duration=5, got %s/%s" % [str(combined.intensity), str(combined.duration)])
	if status_state.get_effective_context_version() <= version_before:
		failures.append("status_state: projected source updates should bump effective context version")

	status_state.remove_projected_source("src_a")
	var reduced: StatusToken = status_state.get_projected_status_token(&"marked")
	if reduced == null or int(reduced.intensity) != 1 or int(reduced.duration) != 5:
		failures.append("status_state: removing one projected source should leave the other contribution intact")


func _verify_status_state_pending_realization(failures: Array[String]) -> void:
	var status_state := StatusState.new()
	var ctx := StatusContext.new()
	ctx.status_id = &"weakened"
	ctx.pending = true
	ctx.intensity = 2
	ctx.duration = 4
	if !status_state.add_or_reapply_ctx(ctx):
		failures.append("status_state: expected pending add_or_reapply_ctx to apply a new token")
		return

	var realize_ctx := StatusContext.new()
	realize_ctx.status_id = &"weakened"
	realize_ctx.pending = true
	if !status_state.realize_pending_ctx(realize_ctx):
		failures.append("status_state: expected pending token to realize successfully")
		return

	var realized := status_state.get_status_token(&"weakened", false)
	if realized == null or int(realized.intensity) != 2 or int(realized.duration) != 4:
		failures.append("status_state: realized token did not preserve pending values")
	if status_state.get_status_token(&"weakened", true) != null:
		failures.append("status_state: pending lane should be empty after realization")


func _verify_pending_and_realized_aura_projection_merge(failures: Array[String]) -> void:
	var shared_fervor_proto := load("res://statuses/shared_fervor.tres")
	if shared_fervor_proto == null:
		failures.append("aura_projection_merge: missing shared_fervor proto")
		return
	var api := _make_api([shared_fervor_proto], [
		{"id": 11, "team": 0},
		{"id": 12, "team": 0},
	])
	var state := api.state
	var source: CombatantState = state.get_unit(11)
	var target: CombatantState = state.get_unit(12)
	state.projection_bank.track_status_aura(source.id, shared_fervor_proto.get_id())

	var realized_ctx := StatusContext.new()
	realized_ctx.status_id = shared_fervor_proto.get_id()
	realized_ctx.intensity = 2
	source.statuses.add_or_reapply_ctx(realized_ctx)

	var pending_ctx := StatusContext.new()
	pending_ctx.status_id = shared_fervor_proto.get_id()
	pending_ctx.pending = true
	pending_ctx.intensity = 3
	source.statuses.add_or_reapply_ctx(pending_ctx)

	SimStatusSystem.refresh_cached_projected_statuses_for_unit(api, target.id, [], true)
	var might_token := target.statuses.get_projected_status_token(&"might")
	if might_token == null:
		failures.append("aura_projection_merge: expected projected might from live pending+realized shared fervor")
		return
	if bool(might_token.pending):
		failures.append("aura_projection_merge: projected token should collapse to non-pending output")
	if int(might_token.intensity) != 5:
		failures.append("aura_projection_merge: expected projected might intensity 5, got %s" % [str(might_token.intensity)])


func _verify_pending_modifier_preview(failures: Array[String]) -> void:
	var might_proto := load("res://statuses/might.tres")
	if might_proto == null:
		failures.append("pending_modifier_preview: missing might proto")
		return

	var api := _make_api([might_proto], [{"id": 21, "team": 0}])
	var source := api.state.get_unit(21)

	var status_ctx := StatusContext.new()
	status_ctx.source_id = 21
	status_ctx.target_id = 21
	status_ctx.status_id = might_proto.get_id()
	status_ctx.pending = true
	status_ctx.intensity = 3
	api.apply_status(status_ctx)

	var ai_ctx := NPCAIContext.new()
	ai_ctx.api = api
	ai_ctx.cid = 21
	ai_ctx.combatant_state = source
	ai_ctx.combatant_data = source.combatant_data

	var components := PendingIntentModifierResolver.get_attack_display_components(ai_ctx, 5, 0, 21)
	if int(components.get("total", -1)) != 8:
		failures.append("pending_modifier_preview: expected live pending might to preview 8 total damage")


func _verify_pending_duration_and_group_expiration(failures: Array[String]) -> void:
	var marked_proto := load("res://statuses/marked.tres")
	var suppressed_proto := load("res://statuses/suppressed.tres")
	if marked_proto == null or suppressed_proto == null:
		failures.append("pending_lifecycle: missing marked or suppressed proto")
		return

	var api := _make_api([marked_proto, suppressed_proto], [{"id": 31, "team": 0}])

	var marked_ctx := StatusContext.new()
	marked_ctx.source_id = 31
	marked_ctx.target_id = 31
	marked_ctx.status_id = marked_proto.get_id()
	marked_ctx.pending = true
	marked_ctx.duration = 2
	api.apply_status(marked_ctx)

	SimStatusSystem.on_actor_turn_end(api, 31)
	var marked_token := api.state.get_unit(31).statuses.get_status_token(marked_proto.get_id(), true)
	if marked_token == null or int(marked_token.duration) != 1:
		failures.append("pending_lifecycle: pending duration token should tick on actor turn end")

	var suppressed_ctx := StatusContext.new()
	suppressed_ctx.source_id = 31
	suppressed_ctx.target_id = 31
	suppressed_ctx.status_id = suppressed_proto.get_id()
	suppressed_ctx.pending = true
	suppressed_ctx.intensity = 2
	api.apply_status(suppressed_ctx)

	SimStatusSystem.on_group_turn_end(api, 0)
	if api.state.get_unit(31).statuses.get_status_token(suppressed_proto.get_id(), true) != null:
		failures.append("pending_lifecycle: pending group-turn-end status should expire like a live token")


func _verify_realization_does_not_reapply_pending_on_apply_hooks(failures: Array[String]) -> void:
	var marked_proto := load("res://statuses/marked.tres")
	if marked_proto == null:
		failures.append("pending_realize_hooks: missing marked proto")
		return

	var api := _make_api([marked_proto], [
		{"id": 41, "team": 0},
		{"id": 42, "team": 0},
	])

	var other_marked := StatusContext.new()
	other_marked.source_id = 42
	other_marked.target_id = 42
	other_marked.status_id = marked_proto.get_id()
	api.apply_status(other_marked)

	var pending_marked := StatusContext.new()
	pending_marked.source_id = 41
	pending_marked.target_id = 41
	pending_marked.status_id = marked_proto.get_id()
	pending_marked.pending = true
	pending_marked.duration = 2
	api.apply_status(pending_marked)

	if api.state.get_unit(42).statuses.has_any(marked_proto.get_id()):
		failures.append("pending_realize_hooks: pending marked should trigger on_apply and clear sibling marks")
		return

	api.apply_status(other_marked)
	api.realize_pending_statuses(41, 41, "verify_pending_realize")
	if !api.state.get_unit(42).statuses.has_any(marked_proto.get_id()):
		failures.append("pending_realize_hooks: realizing pending marked should not rerun on_apply")


func _make_api(status_protos: Array, unit_specs: Array[Dictionary]) -> SimBattleAPI:
	var state := BattleState.new()
	state.units = {}
	state.status_catalog = StatusCatalog.new()
	state.projection_bank = ProjectionBank.new()

	for proto in status_protos:
		if proto != null:
			state.status_catalog.by_id[proto.get_id()] = proto

	var group_orders := {
		0: [],
		1: [],
	}
	for spec in unit_specs:
		var unit := CombatantState.new()
		unit.id = int(spec.get("id", 0))
		unit.team = int(spec.get("team", 0))
		unit.max_health = 10
		unit.health = 10
		unit.alive = true
		unit.statuses = StatusState.new()
		unit.combatant_data = CombatantData.new()
		state.units[unit.id] = unit
		group_orders[unit.team].append(unit.id)

	state.groups[0].order = PackedInt32Array(group_orders[0])
	state.groups[1].order = PackedInt32Array(group_orders[1])
	return SimBattleAPI.new(state)
