# damage_context.gd
class_name DamageContext
extends RefCounted

enum Phase {
	PRE_MODIFIERS,
	POST_MODIFIERS,
	PRE_APPLICATION,
	APPLIED
}

# ModifierPolicy is a bitflag enum so future chain effects can opt out of
# attacker-side and/or defender-side modifier passes independently.
enum ModifierPolicy {
	APPLY_ALL = 0,
	SKIP_DEAL_MODIFIERS = 1,
	SKIP_TAKE_MODIFIERS = 2,
}

var api: SimBattleAPI
#var source: Fighter = null
var source_id: int = 0

#var target: Fighter = null
var target_id: int = 0

# What we *intend* to do
var base_amount: int = 0
var base_banish_amount: int = 0

# What we're *currently* going to do (statuses/mods can change this)
var amount: int = 0
var display_amount: int = 0
var banish_amount: int = 0
var applied_banish_amount: int = 0

# Type tags for modifier lookups, logging, conditional statuses, etc.
var deal_modifier_type: int = Modifier.Type.DMG_DEALT
var take_modifier_type: int = Modifier.Type.DMG_TAKEN
var modifier_policy: int = ModifierPolicy.APPLY_ALL

# Results (filled in when applied)
var before_health: int = 0
var after_health: int = 0
var health_damage: int = 0
var was_lethal: bool = false
var overflow_amount: int = 0
var overflow_banish_amount: int = 0

# Optional flags / tags
var tags: Array[StringName] = []
var reason: String = ""
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""
var phase: Phase = Phase.PRE_MODIFIERS
var params := {}
var event_extra := {}
var sound: Sound
#func _init(_source: Fighter, _target: Fighter, _base: int) -> void:
	#source = _source
	#target = _target
	#base_amount = _base
	#amount = _base
