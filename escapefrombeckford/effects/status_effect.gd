# status_effect.gd

class_name StatusEffect extends Effect

var status_id: StringName = &""
var source: Fighter = null # optional, but nice for procs/logging
var duration: int = 0
var intensity: int = 0

func execute(api: BattleAPI) -> void:
	if !api:
		return

	api.play_sfx(sound)

	if status_id == &"":
		push_warning("StatusEffect.execute(): status_id is empty")
		return

	for target in targets:
		if !target:
			continue

		var ctx := StatusContext.new()
		ctx.source = source
		ctx.target = target

		# ID-based
		ctx.status_id = status_id
		ctx.duration = duration
		ctx.intensity = intensity

		ctx.hydrate_ids()
		api.apply_status(ctx)
