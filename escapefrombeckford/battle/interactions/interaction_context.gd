# interaction_context.gd
class_name InteractionContext
extends RefCounted

var handler: BattleInteractionHandler

func enter() -> void: pass
func exit() -> void: pass

# "primary" = prompt button (OK or Cancel depending on mode)
func on_primary() -> void: pass

# Optional hooks (safe no-ops)
func on_hover(_f: CombatantView) -> void: pass
func on_unhover(_f: CombatantView) -> void: pass
func on_click(_f: CombatantView) -> void: pass

func needs_more_selections() -> bool:
	return true
