class_name EchoedCrueltyStatus extends Status

#var member_var := 0

func init_status(target: Node) -> void:
	status_changed.connect(_on_status_changed.bind(target))
	_on_status_changed(target)

func apply_status(target: Node) -> void:
	print("Status applied: Echoed Cruelty")
	#print("Gets status extent of %s" % member_var)
	#status_applied.emit(self)

## START HERE AGAIN TO DO THE AURA THING
#func _on_status_changed(target: Node) -> void:
	#var status_effect := StatusEffect.new()
	#var aura_2ary_status := secondary_status.duplicate(true)
	#aura_2ary_status.intensity = cruel_dominion_intensity
	#status_effect.sound = card_data.sound
	#status_effect.status = aura_2ary_status
	#status_effect.execute()
	
	#This stuff is code for testing that buffs the work on the source.
	assert(target.get("modifier_system"), "No modifier on %s" % target)
	
	var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	
	var echoed_cruelty_modifier_value := dmg_dealt_modifier.get_value("echoed cruelty")
	
	if !echoed_cruelty_modifier_value:
		echoed_cruelty_modifier_value = ModifierValue.create_new_modifier("echoed cruelty", ModifierValue.Type.FLAT)
	
	echoed_cruelty_modifier_value.flat_value = intensity
	dmg_dealt_modifier.add_new_value(echoed_cruelty_modifier_value)
	
	
