class_name AmplifyStatus extends Status

const AMPLIFY_ID := "amplify"
const MODIFIER := 0.5

func init_status(target: Node) -> void:
	assert(target.get("modifier_system"), "No modifier on %s" % target)
	var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	var amplify_modifier_value := dmg_dealt_modifier.get_value(AMPLIFY_ID)
	
	if !amplify_modifier_value:
		amplify_modifier_value = ModifierValue.create_new_modifier(AMPLIFY_ID, ModifierValue.Type.MULT)
		amplify_modifier_value.mult_value = MODIFIER
		dmg_dealt_modifier.add_new_value(amplify_modifier_value)
	if !status_changed.is_connected(_on_status_changed):
		status_changed.connect(_on_status_changed.bind(dmg_dealt_modifier))
	#print("amplify.gd init_status() target: %s" % target)
	#_on_status_changed(target)
#
#func apply_status(_target: Node) -> void:
	#status_applied.emit(self)
	#print("%s should take %s%% more damage." % [_target, MODIFIER*100])

func _on_status_changed(dmg_dealt_modifier: Modifier) -> void:
	if duration <= 0 and dmg_dealt_modifier:
		dmg_dealt_modifier.remove_value(AMPLIFY_ID)
