
class_name EncounterSetFlagAction extends EncounterAction

@export var flag_name: StringName = &""
@export var value: Variant = true

func execute(ctx) -> void:
	if ctx == null or ctx.director == null or flag_name == &"":
		return
	ctx.director.set_flag(flag_name, value)
