class_name GateResult extends RefCounted

enum Verdict {
	ALLOW,
	DENY,
	DEFER,
}

var verdict: int = Verdict.ALLOW
var reason_id: StringName = &""
var player_message: String = ""
var allowed_target_ids: PackedInt32Array = PackedInt32Array()
var allowed_insert_indices: PackedInt32Array = PackedInt32Array()
var followup_step_id: StringName = &""
var dialogue_request = null
