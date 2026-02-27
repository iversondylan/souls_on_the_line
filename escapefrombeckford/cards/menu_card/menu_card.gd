class_name MenuCard extends CenterContainer

signal tooltip_requested(card_data: CardData)

@export var card_data: CardData : set = set_card_data
@onready var visuals: CardVisuals = $Visuals

# Must be set by parent (Run / Shop / Collection)
var player_data: PlayerData

func set_card_data(new_card_data: CardData) -> void:
	card_data = new_card_data
	visuals.card_data = card_data
	visuals.set_description(get_description())

func get_description() -> String:
	var text := card_data.description
	var resolved := CardResolvedTarget.new()
	
	var ctx := CardActionContext.new()
	ctx.card_data = card_data
	ctx.resolved_target = resolved
	
	for action: CardAction in card_data.actions:
		var total_slots := TextUtils.count_placeholders(text)
		
		# If there are no placeholders left, switch to modular append behavior.
		if total_slots <= 0:
			var extra := action.get_modular_description(ctx)
			if extra != null and extra != "":
				# append with a leading space (as requested)
				text += " " + extra
			continue

		var consume := action.description_arity()
		if consume <= 0:
			# This action doesn't consume placeholders; leave text unchanged
			# (modular append happens only when total_slots == 0, handled above)
			continue

		var values := action.get_description_values(ctx)
		# You can keep this assert if you want strict authoring:
		# assert(values.size() == consume)

		# We apply at most the number of placeholders available.
		# If the action returned MORE values than placeholders, that's the only error case.
		var apply_n : int = min(values.size(), total_slots)
		if values.size() > total_slots:
			push_error(
				"UsableCard.get_description(): action returned %s values but only %s placeholders remain. Truncating."
				% [values.size(), total_slots]
			)

		# Build formatting args: fill remaining slots with "%s" so placeholders persist.
		var args: Array = []
		for i in range(apply_n):
			args.append(values[i])

		for i in range(total_slots - apply_n):
			args.append("%s")

		text = text % args

	text = text.replace("{percent}", "%")
	text = TextUtils.percent_to_symbol(text)
	text = TextUtils.end_with_period(text)
	return text

func _on_visuals_mouse_entered() -> void:
	visuals.glow.show()

func _on_visuals_mouse_exited() -> void:
	visuals.glow.hide()

func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		tooltip_requested.emit(card_data)
