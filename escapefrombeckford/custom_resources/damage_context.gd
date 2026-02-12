# damage_context.gd
class_name DamageContext
extends RefCounted

enum Phase {
	PRE_MODIFIERS,
	POST_MODIFIERS,
	APPLIED
}
var api: BattleAPI
var source: Fighter = null
var source_id: int = 0

var target: Fighter = null
var target_id: int = 0

# What we *intend* to do
var base_amount: int = 0

# What we're *currently* going to do (statuses/mods can change this)
var amount: int = 0

# Type tags for modifier lookups, logging, conditional statuses, etc.
var deal_modifier_type: int = Modifier.Type.DMG_DEALT
var take_modifier_type: int = Modifier.Type.DMG_TAKEN

# Results (filled in when applied)
var armor_damage: int = 0
var health_damage: int = 0
var was_lethal: bool = false

# Optional flags / tags (handy later)
var tags: Array[StringName] = []
var phase: Phase = Phase.PRE_MODIFIERS

#func _init(_source: Fighter, _target: Fighter, _base: int) -> void:
	#source = _source
	#target = _target
	#base_amount = _base
	#amount = _base
