extends SceneTree

const EffectiveStatusContextCacheStore := preload("res://battle/sim/containers/effective_status_context_cache_store.gd")
const PendingStatusSourceSet := preload("res://battle/sim/containers/pending_status_source_set.gd")
const ProjectionImpactInfo := preload("res://battle/sim/containers/projection_impact_info.gd")
const ProjectionSourceEntry := preload("res://battle/sim/containers/projection_source_entry.gd")
const ProjectionBank := preload("res://battle/sim/containers/projection_bank.gd")
const SimStatusContext := preload("res://battle/sim/containers/sim_status_context.gd")
const StatusState := preload("res://battle/sim/containers/status_state.gd")
const StatusContext := preload("res://battle/contexts/status_context.gd")
const StatusStack := preload("res://battle/sim/containers/status_stack.gd")


func _initialize() -> void:
	var failures: Array[String] = []

	_verify_pending_status_source_set(failures)
	_verify_projection_impact_info_merge(failures)
	_verify_effective_status_context_cache_store(failures)
	_verify_projection_bank_entries(failures)
	_verify_status_state_projection_aggregation(failures)
	_verify_status_state_pending_realization(failures)

	if failures.is_empty():
		print("STATUS PROJECTION TYPING VERIFY OK")
		quit()
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_pending_status_source_set(failures: Array[String]) -> void:
	var pending_sources := PendingStatusSourceSet.new()
	pending_sources.include_source(5)
	pending_sources.include_source(2)
	pending_sources.include_source(5)
	pending_sources.include_source(9)

	if pending_sources.signature() != "2,5,9":
		failures.append("pending_status_source_set: expected stable signature 2,5,9")
	if !pending_sources.has_source(5) or pending_sources.has_source(7):
		failures.append("pending_status_source_set: membership check failed")


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
	store.set_contexts(3, 7, "2,5", false, empty_contexts)

	if !store.has_contexts(3, 7, "2,5", false):
		failures.append("effective_status_context_cache_store: expected cached empty array to count as a hit")
	if store.has_contexts(3, 7, "2,5", true):
		failures.append("effective_status_context_cache_store: allow_dead should be part of the cache key")

	store.invalidate()
	if store.has_contexts(3, 7, "2,5", false):
		failures.append("effective_status_context_cache_store: invalidate should clear cached entries")


func _verify_projection_bank_entries(failures: Array[String]) -> void:
	var bank := ProjectionBank.new()
	if !bank.track_status_aura(8, &"alpha", true):
		failures.append("projection_bank: expected initial aura track to change the bank")
	bank.track_status_aura(3, &"beta", false)

	var entries: Array[ProjectionSourceEntry] = bank.get_entries()
	if entries.size() != 2:
		failures.append("projection_bank: expected 2 typed entries, got %d" % entries.size())
		return
	if !(entries[0] is ProjectionSourceEntry) or !(entries[1] is ProjectionSourceEntry):
		failures.append("projection_bank: expected ProjectionSourceEntry results from get_entries()")
	if entries[0].get_source_key() != ProjectionSourceEntry.make_source_key(entries[0].source_kind, entries[0].source_owner_id, entries[0].source_id, entries[0].pending):
		failures.append("projection_bank: source key helper mismatch")


func _verify_status_state_projection_aggregation(failures: Array[String]) -> void:
	var status_state := StatusState.new()
	var projected_a := StatusStack.new(&"marked")
	projected_a.intensity = 2
	projected_a.duration = 3
	var projected_b := StatusStack.new(&"marked")
	projected_b.intensity = 1
	projected_b.duration = 5

	var version_before := status_state.get_effective_context_version()
	var source_a_stacks: Array[StatusStack] = [projected_a]
	var source_b_stacks: Array[StatusStack] = [projected_b]
	status_state.upsert_projected_source("src_a", source_a_stacks)
	status_state.upsert_projected_source("src_b", source_b_stacks)
	var combined: StatusStack = status_state.get_projected_status_stack(&"marked")
	if combined == null:
		failures.append("status_state: expected projected marked stack after two sources")
		return
	if int(combined.intensity) != 3 or int(combined.duration) != 5:
		failures.append("status_state: projected aggregation expected intensity=3 duration=5, got %s/%s" % [str(combined.intensity), str(combined.duration)])
	if status_state.get_effective_context_version() <= version_before:
		failures.append("status_state: projected source updates should bump effective context version")

	status_state.remove_projected_source("src_a")
	var reduced: StatusStack = status_state.get_projected_status_stack(&"marked")
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
		failures.append("status_state: expected pending add_or_reapply_ctx to apply a new stack")
		return

	var realize_ctx := StatusContext.new()
	realize_ctx.status_id = &"weakened"
	realize_ctx.pending = true
	if !status_state.realize_pending_ctx(realize_ctx):
		failures.append("status_state: expected pending stack to realize successfully")
		return

	var realized := status_state.get_status_stack(&"weakened", false)
	if realized == null or int(realized.intensity) != 2 or int(realized.duration) != 4:
		failures.append("status_state: realized stack did not preserve pending values")
	if status_state.get_status_stack(&"weakened", true) != null:
		failures.append("status_state: pending lane should be empty after realization")
