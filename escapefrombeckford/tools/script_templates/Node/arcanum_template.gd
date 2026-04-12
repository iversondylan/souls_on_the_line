# meta-name: Arcanum
# meta-description: Create a new Arcanum with its own behavior.
class_name MyNewArcanum extends Arcanum

var member_var := 0

func get_timed_proc_flags() -> int:
	return TimedProc.BATTLE_START

func initialize_arcanum(_arcanum_display: ArcanumDisplay) -> void:
	print("arcanum.gd initialize_arcanum(): This happens once when arcanum is acquired.")

func on_battle_start(_ctx: SimArcanumContext) -> void:
	print("arcanum.gd on_battle_start(): This happens when the arcanum script implements that hook.")

func deactivate_arcanum(_arcanum_display: ArcanumDisplay) -> void:
	print("arcanum.gd deactivate_arcanum(): this gets called when an ArcanumDisplay is exiting scene tree.")
	print("Event-based arcana should disconnect from Events bus here.")

# we can provide unique tooltips per arcanum
func get_tooltip() -> String:
	return tooltip_description
