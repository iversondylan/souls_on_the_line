class_name CrueltyEchoes extends AuraSecondary

const PRIMARY_ID: String = "echoed cruelty"

var member_var := 0

func init_status(target: Node) -> void:
	status_changed.connect(_on_status_changed.bind(target))
	#print("cruelty_echoes.gd init_status() target: %s" % target)
	_on_status_changed(target)

func apply_status(_target: Node) -> void:
	pass
	#print("cruelty_echoes.gd apply_status() target: %s" % _target)

func _on_status_changed(target: Node) -> void:
	#print("cruelty_echoes.gd _on_status_changed() stacks: %s" % intensity)
	#print("cruelty_echoes.gd _on_status_changed() target: %s" % target)
	assert(target.get("modifier_system"), "No modifier on %s" % target)
	
	var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	
	var echoed_cruelty_modifier_value := dmg_dealt_modifier.get_value(PRIMARY_ID)
	
	if !echoed_cruelty_modifier_value:
		echoed_cruelty_modifier_value = ModifierValue.create_new_modifier(PRIMARY_ID, ModifierValue.Type.FLAT)
	
	echoed_cruelty_modifier_value.flat_value = intensity
	dmg_dealt_modifier.add_new_value(echoed_cruelty_modifier_value)
