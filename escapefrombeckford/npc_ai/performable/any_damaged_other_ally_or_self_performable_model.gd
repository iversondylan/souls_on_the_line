class_name AnyDamagedOtherAllyOrSelfPerformableModel
extends PerformableModel

func is_performable_sim(ctx: NPCAIContext) -> bool:
	return PseudoRandomDamagedOtherAllyElseSelfStatusTargetModel.find_target_id(ctx) > 0
