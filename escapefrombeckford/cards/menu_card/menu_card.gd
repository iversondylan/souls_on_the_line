class_name MenuCard extends CenterContainer

signal tooltip_requested(card_data: CardData)

@export var card_data: CardData : set = set_card_data
@onready var visuals: CardVisuals = $Visuals

var player_data: PlayerData

func set_card_data(new_card_data: CardData) -> void:
	card_data = new_card_data
	visuals.card_data = card_data
	visuals.set_description(get_description())

func get_description() -> String:
	var text := card_data.description

	# Build preview context
	#var resolved := resolve_targets(targets)

	var ctx := CardActionContext.new()
	#ctx.player = player
	#ctx.battle_scene = battle_scene
	ctx.card_data = card_data
	ctx.resolved_target = CardResolvedTarget.new()

	for action: CardAction in card_data.actions:
		var total_slots := TextUtils.count_placeholders(text)
		var consume := action.description_arity()
		
		if consume == 0:
			continue
		
		assert(total_slots >= consume)
		
		var values := action.get_description_values(ctx)
		
		assert(values.size() == consume)
		
		# Fill remaining slots with "%s" to preserve them
		var args: Array = []
		args.append_array(values)
		for i in range(total_slots - consume):
			args.append("%s")
		
		text = text % args
	
	return text

func _on_visuals_mouse_entered() -> void:
	visuals.glow.show()

func _on_visuals_mouse_exited() -> void:
	visuals.glow.hide()

func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		tooltip_requested.emit(card_data)
