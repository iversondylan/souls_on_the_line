# attack_intent_tooltip_text_model.gd

class_name AttackIntentTooltipTextModel extends TextModel

@export_multiline var text_template: String = "[b]Attack Intent[/b] [{attack_mode} attack]: {strikes}{damage} damage."

func get_text(ctx: NPCAIContext) -> String:
	if !ctx or !ctx.params:
		return text_template
	
	var result := text_template
	
	# ---- Attack mode ----
	var mode_raw := str(ctx.params.get(NPCKeys.ATTACK_MODE, ""))
	var mode_text := ""
	
	match mode_raw:
		NPCAttackSequence.ATTACK_MODE_MELEE:
			mode_text = "Melee"
		NPCAttackSequence.ATTACK_MODE_RANGED:
			mode_text = "Ranged"
		_:
			mode_text = "Standard"
	
	result = result.replace("{attack_mode}", mode_text)
	
	# ---- Strikes ----
	var strikes := int(ctx.params.get(NPCKeys.STRIKES, 1))
	var strikes_text := ""
	
	if strikes >= 2:
		strikes_text = "%d strikes of " % strikes
	
	result = result.replace("{strikes}", strikes_text)
	
	# ---- Damage ----
	var damage := int(ctx.params.get(NPCKeys.DAMAGE, 0))
	damage = ctx.combatant.modifier_system.get_modified_value(damage, Modifier.Type.DMG_DEALT)
	result = result.replace("{damage}", "%d" % damage)
	
	return result
