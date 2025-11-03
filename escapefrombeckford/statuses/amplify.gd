class_name AmplifyStatus extends Status

const AMPLIFY_ID := "amplify"
const MODIFIER := 0.5

func init_status(target: Node) -> void:
	status_changed.connect(_on_status_changed.bind(target))
	_on_status_changed(target)

func apply_status(target: Node) -> void:
	print("Status applied: %s" % AMPLIFY_ID)
	#print("Gets status extent of %s" % member_var)
	status_applied.emit(self)

func _on_status_changed(target: Node) -> void:
	print("amplify.gd _on_status_changed() stacks: %s" % duration)
	
	#This stuff is code for testing that buffs the work on the source.
	assert(target.get("modifier_system"), "No modifier on %s" % target)
	
	var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	
	var echoed_cruelty_modifier_value := dmg_dealt_modifier.get_value(AMPLIFY_ID)
	
	if !echoed_cruelty_modifier_value:
		echoed_cruelty_modifier_value = ModifierValue.create_new_modifier(AMPLIFY_ID, ModifierValue.Type.MULT)
	
	echoed_cruelty_modifier_value.mult_value = MODIFIER
	dmg_dealt_modifier.add_new_value(echoed_cruelty_modifier_value)
