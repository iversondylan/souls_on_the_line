extends Arcanum

var member_var := 0

func initialize_arcanum(_arcanum_display: ArcanumDisplay) -> void:
	print("arcanum.gd initialize_arcanum(): unrly pyric wraps.")

func activate_arcanum(arcanum_display: ArcanumDisplay) -> void:
	arcanum_display.flash()
	#print("arcanum.gd activate_arcanum(): This happens at specific times based on the Relic.Type property.")

func deactivate_arcanum(_arcanum_display: ArcanumDisplay) -> void:
	print("arcanum.gd deactivate_arcanum(): this gets called when an ArcanumDisplay is exiting scene tree.")
	print("Event-based arcana should disconnect from Events bus here.")

# we can provide unique tooltips per arcanum
func get_tooltip() -> String:
	return tooltip_description
