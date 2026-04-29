class_name PointToNodeEncounterAction extends EncounterAction

@export var anchor_path: NodePath
@export var offset: Vector2 = Vector2(0, -90)
@export var clear_existing: bool = true

func execute(ctx: EncounterRuleContext) -> void:
	if ctx == null or ctx.battle == null:
		return
	var anchor := ctx.battle.get_node_or_null(anchor_path)
	ctx.battle.point_encounter_arrow_to_node(anchor, offset, clear_existing)
