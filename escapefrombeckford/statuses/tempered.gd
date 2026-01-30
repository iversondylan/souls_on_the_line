class_name TemperedStatus extends Status

const AMPLIFY_ID := "tempered"
var max_health_per_strike := 2

func on_damage_taken(ctx: DamageContext) -> void:
	if ctx.health_damage > 0 and !ctx.was_lethal:
		intensity += max_health_per_strike
		status_parent.combatant_data.max_health += max_health_per_strike
		status_parent.combatant_data.heal(max_health_per_strike)
		

func get_tooltip() -> String:
	var base_tooltip: String
	base_tooltip = "Tempered: gains %s maximum health for each strike survived. +%s maximum health."
	return base_tooltip % [max_health_per_strike, intensity]
