class_name KeepStabilityPerformableModel extends PerformableModel

func is_performable(ctx: NPCAIContext) -> bool:
	return !ctx.state.get(
		NPCAIBehavior.STABILITY_BROKEN,
		false
	)
