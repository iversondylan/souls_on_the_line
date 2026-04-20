# Backward-compatibility shim. Source-change orchestration now lives in
# TransformerRegistry; callers should route there directly.
class_name ProjectionChangeSystem
extends RefCounted


static func sync_status_source(
	api,
	source_owner_id: int,
	status_id: StringName
) -> void:
	if api == null or api.state == null:
		return
	var owner: CombatantState = api.state.get_unit(source_owner_id)
	if owner == null or owner.statuses == null:
		return
	for token: StatusToken in owner.statuses.get_all_tokens(true):
		if token == null or StringName(token.id) != status_id:
			continue
		api.state.transformer_registry.sync_source_change(
			api,
			TransformerSourceRef.for_status_token(
				source_owner_id,
				int(owner.team),
				status_id,
				int(token.token_id)
			)
		)


static func sync_arcanum_source(
	api,
	source_owner_id: int,
	source_group_index: int,
	arcanum_id: StringName
) -> void:
	if api == null or api.state == null or api.state.transformer_registry == null:
		return
	api.state.transformer_registry.sync_source_change(
		api,
		TransformerSourceRef.for_arcanum_entry(source_owner_id, source_group_index, arcanum_id)
	)
