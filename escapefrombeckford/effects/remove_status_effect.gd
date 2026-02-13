# remove_status_effect.gd
class_name RemoveStatusEffect
extends Effect

var status_id: StringName
var source: Fighter = null
var remove_all_stacks: bool = false

func execute(api: BattleAPI) -> void:
	if !api:
		return

	api.play_sfx(sound)

	if status_id == &"":
		push_warning("RemoveStatusEffect.execute(): status_id empty")
		return

	for target in targets:
		if !target:
			continue

		var ctx := RemoveStatusContext.new()
		ctx.source = source
		ctx.target = target
		ctx.status_id = status_id
		ctx.remove_all_stacks = remove_all_stacks
		ctx.hydrate_ids()

		api.remove_status(ctx)
