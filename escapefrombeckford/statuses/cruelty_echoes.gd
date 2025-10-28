class_name CrueltyEchoes extends Status

var member_var := 0

func init_status(target: Node) -> void:
	status_changed.connect(_on_status_changed.bind(target))
	_on_status_changed(target)

func apply_status(_target: Node) -> void:
	print("Status applied: Cruelty Echoes")

func _on_status_changed(target: Node) -> void:
	print("cruelty_echoes.gd _on_status_changed()")
	#assert(target.get("modifier_system"), "No modifier on %s" % target)
	#
	#var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	#assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	#
	#var echoed_cruelty_modifier_value := dmg_dealt_modifier.get_value("echoed cruelty")
	#
	#if !echoed_cruelty_modifier_value:
		#echoed_cruelty_modifier_value = ModifierValue.create_new_modifier("echoed cruelty", ModifierValue.Type.FLAT)
	#
	#echoed_cruelty_modifier_value.flat_value = intensity
	#dmg_dealt_modifier.add_new_value(echoed_cruelty_modifier_value)
