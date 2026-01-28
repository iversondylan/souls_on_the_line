# damage_context.gd

class_name DamageContext
extends RefCounted

var source: Fighter
var target: Fighter

# Inputs (set before resolution)
var base_amount: int = 0                  # from attacker-side calc (already includes DMG_DEALT if you do it there)
var modifier_type: Modifier.Type          # usually DMG_TAKEN on the target
var tags: int = 0                         # optional bitflags later (SPELL, MELEE, AOE, TRUE_DAMAGE...)

# Working / resolved values (filled during resolution)
var final_amount: int = 0                 # after target modifiers, before armor
var health_loss: int = 0                  # after armor
var blocked: bool = false                 # health_loss == 0
var lethal: bool = false
