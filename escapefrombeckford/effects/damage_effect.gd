# damage_effect.gd

class_name DamageEffect extends Effect

@export var deal_modifier_type := Modifier.Type.DMG_DEALT
@export var take_modifier_type := Modifier.Type.DMG_TAKEN
@export var use_modifiers := true

var n_damage: int = 0
var source: Fighter = null
var modifier_type: Modifier.Type
var params := {}

func execute(api: BattleAPI) -> void:
	if !api:
		return

	for t: Fighter in targets:
		if !t:
			continue

		var ctx := DamageContext.new()
		ctx.source = source
		if source:
			ctx.source_id = source.combat_id

		ctx.target = t
		ctx.target_id = t.combat_id

		ctx.base_amount = n_damage
		print("damage_effect.gd execute() [building a DamageContext] base amount: ", ctx.base_amount)
		# IMPORTANT: these are what enable DMG_DEALT / DMG_TAKEN
		if use_modifiers:
			ctx.deal_modifier_type = deal_modifier_type
			ctx.take_modifier_type = take_modifier_type
		else:
			ctx.deal_modifier_type = Modifier.Type.NO_MODIFIER
			ctx.take_modifier_type = Modifier.Type.NO_MODIFIER
		ctx.sound = sound
		
		api.resolve_damage_immediate(ctx)

#func execute(api: BattleAPI) -> void:
	#if !api:
		#return
#
	#for target in targets:
		#if !target:
			#continue
#
		#var ctx := DamageContext.new(source, target, n_damage)
		#ctx.api = api
#
		## Populate ids so sim can work later, and live can survive freed nodes.
		#if source:
			#ctx.source_id = source.combat_id
		#if target:
			#ctx.target_id = target.combat_id
#
		#api.resolve_damage(ctx)
#
	#api.play_sfx(sound)



## damage_effect.gd
#class_name DamageEffect extends Effect
#
#var n_damage: int = 0
#var source: Fighter = null
#var modifier_type: Modifier.Type #CURRENTLY UNUSED, but function should
## be restored so that there can be damage that does not get modified
## or perhaps damage types with particular weakness/resistance
#
#func execute(api: BattleAPI) -> void:
	#if !api:
		#return
#
	#for target in targets:
		#if !target:
			#continue
		#var ctx := DamageContext.new(source, target, n_damage)
		#api.resolve_damage(ctx)
#
	#api.play_sfx(sound)
