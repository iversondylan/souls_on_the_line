# damage_effect.gd

class_name DamageEffect extends Effect

@export var deal_modifier_type := Modifier.Type.DMG_DEALT
@export var take_modifier_type := Modifier.Type.DMG_TAKEN
@export var use_modifiers := true

var n_damage: int = 0
var source: Fighter = null
var modifier_type: Modifier.Type
var params := {}

#func execute(api: BattleAPI) -> void:
	#if !api:
		#return
#
	#for t: Fighter in targets:
		#if !t:
			#continue
#
		#var ctx := DamageContext.new()
		#ctx.source = source
		#if source:
			#ctx.source_id = source.combat_id
#
		#ctx.target = t
		#ctx.target_id = t.combat_id
#
		#ctx.base_amount = n_damage
		##print("damage_effect.gd execute() [building a DamageContext] base amount: ", ctx.base_amount)
		## IMPORTANT: these are what enable DMG_DEALT / DMG_TAKEN
		#if use_modifiers:
			#ctx.deal_modifier_type = deal_modifier_type
			#ctx.take_modifier_type = take_modifier_type
		#else:
			#ctx.deal_modifier_type = Modifier.Type.NO_MODIFIER
			#ctx.take_modifier_type = Modifier.Type.NO_MODIFIER
		#ctx.sound = sound
		#
		#api.resolve_damage_immediate(ctx)
