class_name EchoedCrueltyStatus extends AuraPrimary

#var member_var := 0
const ID = "echoed cruelty"

func init_status(target: Node) -> void:
	status_changed.connect(_on_status_changed.bind(target))
	_on_status_changed(target)

func apply_status(target: Node) -> void:
	pass
	#print("Status applied: Echoed Cruelty")
	#print("Gets status extent of %s" % member_var)
	#status_applied.emit(self)

func _on_status_changed(target: Node) -> void:
	#print("echoed_cruelty.gd _on_status_changed() stacks: %s" % intensity)
	Events.aura_changed.emit(status_parent, self)
	
	#This stuff is code for testing that buffs the work on the source.
	assert(target.get("modifier_system"), "No modifier on %s" % target)
	
	var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	
	var echoed_cruelty_modifier_value := dmg_dealt_modifier.get_value(ID)
	
	if !echoed_cruelty_modifier_value:
		echoed_cruelty_modifier_value = ModifierValue.create_new_modifier(ID, ModifierValue.Type.FLAT)
	
	echoed_cruelty_modifier_value.flat_value = intensity
	dmg_dealt_modifier.add_new_value(echoed_cruelty_modifier_value)
	
func get_tooltip() -> String:
	var base_tooltip: String = "Echoed Cruelty [Aura]: Your allies deal %s additional damage."
	return base_tooltip % intensity
