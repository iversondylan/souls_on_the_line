# card_action.gd

class_name CardAction extends Resource

const EXTRA_CARD_ACTION_TEXT := " -EXTRA CARD ACTION-"

enum InteractionMode {
	NONE,
	PREFLIGHT,
}

func activate_sim(ctx: CardContext) -> bool:
	var cname := ctx.card_data.name if ctx and ctx.card_data else "<no card/ctx>"
	push_error("%s missing activate_sim() (card=%s)" % [get_class(), cname])
	return false

# --- DESCRIPTION CONTRACT ---
# Each CardAction contributes exactly one description slot.
# If no `%s` remains in the template, its overflow text is appended instead.
# --------------------------------

func begin_preflight_interaction(_ctx: CardContext) -> bool:
	return false

func get_preflight_interaction_mode(_ctx: CardContext) -> int:
	return InteractionMode.NONE

func waits_for_async_resolution_after_activate_sim(_ctx: CardContext) -> bool:
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



func get_description_value(_ctx: CardActionContext) -> String:
	return ""

func get_extra_description(_ctx: CardActionContext) -> String:
	return EXTRA_CARD_ACTION_TEXT
