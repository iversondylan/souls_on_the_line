# card_action.gd

class_name CardAction extends Resource

enum InteractionMode {
	NONE,
	PREFLIGHT,
}

func activate_sim(ctx: CardContext) -> bool:
	var cname := ctx.card_data.name if ctx and ctx.card_data else "<no card/ctx>"
	push_error("%s missing activate_sim() (card=%s)" % [get_class(), cname])
	return false

# --- DESCRIPTION CONTRACT ---
# Each CardAction:
# 1. Declares how many placeholders it consumes
# 2. Supplies exactly that many concrete values
# 3. Leaves remaining placeholders intact ("%s") for later actions
# --------------------------------

func begin_preflight_interaction(ctx: CardContext) -> bool:
	return false

func get_preflight_interaction_mode(ctx: CardContext) -> int:
	return InteractionMode.NONE

func waits_for_async_resolution_after_activate_sim(ctx: CardContext) -> bool:
	return false

func starts_compiled_turn_span(_ctx: CardContext) -> bool:
	return false

func get_compiled_turn_span_kind(_ctx: CardContext) -> StringName:
	return &""

func get_compiled_turn_span_actor_id(ctx: CardContext) -> int:
	return int(ctx.source_id) if ctx != null else 0

func joins_compiled_turn_span(
	_ctx: CardContext,
	_kind: StringName,
	_anchor_action_index: int,
	_span_index: int
) -> bool:
	return false



func description_arity() -> int:
	# Number of %s this action consumes
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	# Return exactly description_arity() values
	return []
#
#func get_modular_description(_ctx: CardActionContext) -> String:
	#return ""
