# card_action.gd

class_name CardAction extends Resource

enum ActionType {
	MELEE_ATTACK,
	DAMAGE,
	BLOCK,
	MOVE,
	STATUS,
	SUMMON,
	HEAL,
	DRAW
}

enum InteractionMode {
	NONE,
	ESCROW,
	CONFIRM
}

@export var action_type: ActionType

@export var requires_enemy: bool = false
@export var requires_target: bool = true

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

func activate_interaction(ctx: CardContext) -> bool:
	return false

func get_interaction_mode(ctx: CardContext) -> int:
	return InteractionMode.NONE

func waits_for_async_resolution_after_activate_sim(ctx: CardContext) -> bool:
	return false



func description_arity() -> int:
	# Number of %s this action consumes
	return 0

#func get_description_values(_ctx: CardActionContext) -> Array:
	## Return exactly description_arity() values
	#return []
#
#func get_modular_description(_ctx: CardActionContext) -> String:
	#return ""
