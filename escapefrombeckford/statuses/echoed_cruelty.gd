class_name EchoedCrueltyStatus extends Aura

const ID := "echoed_cruelty"

@export var flat_bonus_per_stack := 1

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func get_modifier_tokens() -> Array[ModifierToken]:
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.flat_value = intensity * flat_bonus_per_stack
	token.mult_value = 0.0
	token.source_id = ID
	token.owner = status_parent
	token.scope = ModifierToken.Scope.GLOBAL
	token.tags = ["aura"]

	return [token]

func get_tooltip() -> String:
	return "Echoed Cruelty [Aura]: Allies deal %s additional damage." % intensity

#class_name EchoedCrueltyStatus extends AuraPrimary
#
##var member_var := 0
#const ID = "echoed cruelty"
#
#func init_status(target: Node) -> void:
	#status_changed.connect(_on_status_changed.bind(target))
	#_on_status_changed(target)
#
#func apply_status(target: Node) -> void:
	#pass
#
#func _on_status_changed(target: Node) -> void:
	#Events.aura_changed.emit(status_parent, self)
	#
	#assert(target.get("modifier_system"), "No modifier on %s" % target)
	#
	#var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	#assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	#
	#var echoed_cruelty_modifier_value := dmg_dealt_modifier.get_value(ID)
	#
	#if !echoed_cruelty_modifier_value:
		#echoed_cruelty_modifier_value = ModifierValue.create_new_modifier(ID, ModifierValue.Type.FLAT)
	#
	#echoed_cruelty_modifier_value.flat_value = intensity
	#dmg_dealt_modifier.add_new_value(echoed_cruelty_modifier_value)
	#
#func get_tooltip() -> String:
	#var base_tooltip: String = "Echoed Cruelty [Aura]: Your allies deal %s additional damage."
	#return base_tooltip % intensity
