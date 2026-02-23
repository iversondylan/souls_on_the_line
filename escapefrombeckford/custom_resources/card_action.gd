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

@export var action_type: ActionType

@export var requires_enemy: bool = false
#@export var requires_summon_slot: bool = false
@export var requires_target: bool = true

func activate(_ctx: CardActionContext) -> bool:
	push_error("Override activate(ctx) in CardAction.")
	return false

func activate_sim(_ctx: CardActionContextSim) -> bool:
	# default: if an action isn't sim-ready yet, fail loudly
	push_error("%s missing activate_sim()" % get_class())
	return false

# --- DESCRIPTION CONTRACT ---
# Each CardAction:
# 1. Declares how many placeholders it consumes
# 2. Supplies exactly that many concrete values
# 3. Leaves remaining placeholders intact ("%s") for later actions
# --------------------------------

func description_arity() -> int:
	# Number of %s this action consumes
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	# Return exactly description_arity() values
	return []

func get_modular_description(_ctx: CardActionContext) -> String:
	return ""

func requires_summon_slot() -> bool:
	return false
