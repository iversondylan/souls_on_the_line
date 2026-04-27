#card_visuals.gd

class_name CardVisuals extends Control

@onready var glow: Sprite2D = %Glow
@onready var card_front: TextureRect = %CardFront
@onready var cost_blue_sprites: AnimatedSprite2D = %CostBlue
@onready var cost_red_sprites: AnimatedSprite2D = %CostRed
@onready var cost_green_sprites: AnimatedSprite2D = %CostGreen
@onready var cost_container: Sprite2D = %CostContainer
@onready var name_label: Label = %NameLabel
@onready var card_art_rect: TextureRect = %CardArtRect
@onready var description: RichTextLabel = %Description
@onready var rarity_icon: TextureRect = %RarityIcon
@onready var card_type_icon: TextureRect = %CardTypeIcon
@onready var card_strictly_visuals: Node2D = $CardStrictlyVisuals
@onready var cost_label: Label = $CardStrictlyVisuals/CornerMan/CostDisplay/CostLabel
@onready var cost_display: Node2D = %CostDisplay

@onready var soul_stats: Node2D = %SoulStats
@onready var attack_icon: TextureRect = %AttackIcon
@onready var summon_icon: TextureRect = %SummonIcon
@onready var health_panel_icon: TextureRect = %HealthPanelIcon
@onready var action_panel_label: Label = %ActionPanelLabel
@onready var health_panel_label: Label = %HealthPanelLabel

@export var card_angle_limit_flt: float = 180
@export var max_card_spread_angle_flt: float = 38

@export var card_name_base_font_size: int = 20
@export var card_name_min_font_size: int = 6
@export var card_name_h_padding: float = 30
@export var card_name_use_ellipsis_at_min_size: bool = false

const OVERLOAD_PIP := preload("uid://pe4lgl2dwu32")
const OVERLOAD_1_COLOR := Color(1.0, 0.88, 0.22, 1.0)
const OVERLOAD_2_COLOR := Color(1.0, 0.56, 0.12, 1.0)
const OVERLOAD_3_COLOR := Color(0.9, 0.18, 0.18, 1.0)
const OVERLOAD_4_PLUS_COLOR := Color(0.45, 0.06, 0.06, 1.0)
const POSITIVE_STAT_MOD_COLOR := Color(0.35, 1.0, 0.45, 1.0)
const NEGATIVE_STAT_MOD_COLOR := Color(1.0, 0.25, 0.25, 1.0)
const CARD_TYPE_TEXTURES := {
	CardData.CardType.CONVOCATION: preload("res://_assets/sprites/assorted/convocation_white.png"),
	CardData.CardType.SOULBOUND: preload("res://_assets/sprites/assorted/soul_bound_white.png"),
	CardData.CardType.ENCHANTMENT: preload("res://_assets/sprites/assorted/enchantment_white.png"),
	CardData.CardType.EFFUSION: preload("res://_assets/sprites/assorted/effusion_white.png"),
	CardData.CardType.SOULWILD: preload("res://_assets/sprites/assorted/soul_wild_white.png"),
}
const RARITY_TEXTURES := {
	CardData.Rarity.COMMON: preload("res://_assets/sprites/card_elements/beckford_insig_1.png"),
	CardData.Rarity.UNCOMMON: preload("res://_assets/sprites/card_elements/beckford_insig_2.png"),
	CardData.Rarity.RARE: preload("res://_assets/sprites/card_elements/beckford_insig_3.png"),
}
const RARITY_TINTS := {
	CardData.Rarity.COMMON: Color(0.338, 0.36, 0.358, 1.0),
	CardData.Rarity.UNCOMMON: Color(0.049, 0.264, 0.61, 1.0),
	CardData.Rarity.RARE: Color(0.492, 0.088, 0.562, 1.0),
}

@export var card_data: CardData : set = _set_card_data
var cost_red: int = 0 : set = set_cost_red
var cost_green: int = 0 : set = set_cost_green
var cost_blue: int = 0 : set = set_cost_blue
var overload: int = 0
var _card_data_internal: CardData
var _display_total_cost_override: int = -1
var mana_panel_radius: float
var _default_cost_label_modulate: Color = Color.WHITE
var _default_action_panel_label_modulate: Color = Color.WHITE
var _default_health_panel_label_modulate: Color = Color.WHITE
var _default_name_label_font_size: int = 16
var _summon_card_ap_bonus: int = 0
var _summon_card_max_health_bonus: int = 0

func _ready() -> void:
	mana_panel_radius = cost_container.texture.get_size().y * cost_container.scale.y * 0.5 - 0.75
	_default_cost_label_modulate = cost_label.modulate
	_default_action_panel_label_modulate = action_panel_label.modulate
	_default_health_panel_label_modulate = health_panel_label.modulate
	_default_name_label_font_size = name_label.get_theme_font_size("font_size")
	_connect_overload_pip_signals()

	refresh_from_card_data()
	_fit_name_label_text()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_fit_name_label_text()

func set_overload(amount: int) -> void:
	overload = maxi(int(amount), 0)
	for pip in _get_overload_pips():
		if pip.get_parent() == cost_display:
			cost_display.remove_child(pip)
		pip.queue_free()
	for _i in range(overload):
		cost_display.add_child(OVERLOAD_PIP.instantiate())
	_request_overload_pip_reposition()
	_refresh_cost_label_color()

func _set_card_data(value: CardData) -> void:
	assert(value != null, "CardVisuals received null CardData")
	if !is_node_ready():
		await ready
	_card_data_internal = value
	name_label.text = value.name
	_fit_name_label_text()
	refresh_from_card_data()
	card_art_rect.texture = value.texture

func refresh_from_card_data() -> void:
	if !is_node_ready():
		await ready
	_reset_soul_stats()
	if _card_data_internal == null:
		set_overload(0)
		cost_label.text = "0"
		cost_label.modulate = _default_cost_label_modulate
		name_label.text = ""
		_fit_name_label_text()
		_set_card_type_icon(null)
		_set_rarity_icon(null, Color.WHITE)
		return

	_fit_name_label_text()
	set_overload(int(_card_data_internal.overload))
	set_total_cost()
	_set_card_type_icon(CARD_TYPE_TEXTURES.get(_card_data_internal.card_type))
	_set_rarity_icon(
		RARITY_TEXTURES.get(_card_data_internal.rarity),
		RARITY_TINTS.get(_card_data_internal.rarity, Color.WHITE)
	)
	_refresh_soul_stats()

func set_description(new_description: String) -> void:
	description.set_text(new_description)

func set_summon_card_stat_bonuses(ap_bonus: int, max_health_bonus: int) -> void:
	_summon_card_ap_bonus = int(ap_bonus)
	_summon_card_max_health_bonus = int(max_health_bonus)
	if is_node_ready():
		refresh_from_card_data()

func set_display_total_cost_override(new_value: int) -> void:
	_display_total_cost_override = int(new_value)
	if is_node_ready():
		set_total_cost()

func set_total_cost() -> void:
	if _card_data_internal == null:
		return
	var total_cost := _display_total_cost_override
	if total_cost < 0:
		total_cost = int(_card_data_internal.get_total_cost())
	cost_label.text = str(total_cost)
	_refresh_cost_label_color()

func set_cost_red(cost: int) -> void:
	cost_red = cost
	match cost_red:
		0:
			cost_red_sprites.frame = 0
		1:
			cost_red_sprites.frame = 1

func set_cost_green(cost: int) -> void:
	cost_green = cost
	match cost_green:
		0:
			cost_green_sprites.frame = 0
		1:
			cost_green_sprites.frame = 1

func set_cost_blue(cost: int) -> void:
	cost_blue = cost
	match cost_blue:
		0:
			cost_blue_sprites.frame = 0
		1:
			cost_blue_sprites.frame = 1

func _get_overload_pips() -> Array[OverloadPip]:
	var pips: Array[OverloadPip] = []
	for child in cost_display.get_children():
		if child is OverloadPip:
			pips.push_back(child)
	return pips

func reposition_overload_pips() -> void:
	var pips := _get_overload_pips()
	var pip_spread_angle_flt: float = 0
	var current_pip_angle_flt: float = 0
	var pip_angle_increment_flt: float = 0

	if pips.size() >= 2:
		pip_spread_angle_flt = min(card_angle_limit_flt, max_card_spread_angle_flt * (pips.size() - 1))
		current_pip_angle_flt = -pip_spread_angle_flt / 2
		pip_angle_increment_flt = pip_spread_angle_flt / (pips.size() - 1)

	for pip in pips:
		_update_pip_transform(pip, current_pip_angle_flt)
		current_pip_angle_flt += pip_angle_increment_flt


func _connect_overload_pip_signals() -> void:
	if cost_display == null:
		return
	if !cost_display.child_entered_tree.is_connected(_on_cost_display_child_tree_changed):
		cost_display.child_entered_tree.connect(_on_cost_display_child_tree_changed)
	if !cost_display.child_exiting_tree.is_connected(_on_cost_display_child_tree_changed):
		cost_display.child_exiting_tree.connect(_on_cost_display_child_tree_changed)


func _on_cost_display_child_tree_changed(node: Node) -> void:
	if node is OverloadPip:
		_request_overload_pip_reposition()


func _request_overload_pip_reposition() -> void:
	if !is_node_ready():
		return
	call_deferred("reposition_overload_pips")

func get_pip_position(angle_deg_flt: float) -> Vector2:
	var x: float = mana_panel_radius * cos(deg_to_rad(angle_deg_flt + 270))
	var y: float = mana_panel_radius * sin(deg_to_rad(angle_deg_flt + 270))
	return Vector2(x, y)

func _update_pip_transform(pip: OverloadPip, angle_in_drag: float) -> void:
	var pos: Vector2 = get_pip_position(angle_in_drag)
	pip.position = pos

func _refresh_cost_label_color() -> void:
	if cost_label == null:
		return

	match overload:
		0:
			cost_label.modulate = _default_cost_label_modulate
		1:
			cost_label.modulate = OVERLOAD_1_COLOR
		2:
			cost_label.modulate = OVERLOAD_2_COLOR
		3:
			cost_label.modulate = OVERLOAD_3_COLOR
		_:
			cost_label.modulate = OVERLOAD_4_PLUS_COLOR

func _set_card_type_icon(texture: Texture2D) -> void:
	if card_type_icon == null:
		return
	card_type_icon.texture = texture
	card_type_icon.visible = texture != null

func _set_rarity_icon(texture: Texture2D, tint: Color) -> void:
	if rarity_icon == null:
		return
	rarity_icon.texture = texture
	rarity_icon.modulate = tint
	rarity_icon.visible = texture != null

func _fit_name_label_text() -> void:
	if name_label == null:
		return

	var raw_text := name_label.text
	if raw_text.is_empty():
		_clear_name_label_fit_overrides()
		return

	var font := name_label.get_theme_font("font")
	if font == null:
		return

	var base_size := card_name_base_font_size
	if base_size <= 0:
		base_size = _default_name_label_font_size

	var min_size := mini(base_size, card_name_min_font_size)
	var available_width := maxf(0.0, name_label.size.x - card_name_h_padding * 2.0)

	if available_width <= 0.0:
		return

	var chosen_size := min_size

	for font_size in range(base_size, min_size - 1, -1):
		var measured_width := _measure_label_text_width(raw_text, font, font_size)
		if measured_width <= available_width:
			chosen_size = font_size
			break

	_apply_name_label_font_size(chosen_size)

	if card_name_use_ellipsis_at_min_size:
		var final_width := _measure_label_text_width(raw_text, font, chosen_size)
		name_label.clip_text = final_width > available_width
	else:
		name_label.clip_text = false

func _measure_label_text_width(text_value: String, font: Font, font_size: int) -> float:
	var string_size := font.get_string_size(
		text_value,
		name_label.horizontal_alignment,
		-1,
		font_size
	)
	return string_size.x

func _apply_name_label_font_size(font_size: int) -> void:
	name_label.add_theme_font_size_override("font_size", font_size)

func _clear_name_label_fit_overrides() -> void:
	name_label.remove_theme_font_size_override("font_size")
	name_label.clip_text = false

func _reset_soul_stats() -> void:
	soul_stats.hide()
	attack_icon.hide()
	summon_icon.hide()
	action_panel_label.text = "-"
	health_panel_label.text = "-"
	action_panel_label.modulate = _default_action_panel_label_modulate
	health_panel_label.modulate = _default_health_panel_label_modulate

func _refresh_soul_stats() -> void:
	if !_is_soul_stats_card(_card_data_internal):
		return

	soul_stats.show()

	var summon_data := _find_preview_summon_data(_card_data_internal)
	if summon_data == null:
		return

	health_panel_label.text = str(maxi(int(summon_data.max_health) + int(_summon_card_max_health_bonus), 0))
	health_panel_label.modulate = _stat_modulate_for_delta(_summon_card_max_health_bonus, _default_health_panel_label_modulate)

	var action_match: Dictionary = _find_first_soul_action_package(summon_data)
	if action_match.is_empty():
		return

	var ctx := _build_soul_preview_context(summon_data)
	var pkg := action_match.get("package") as NPCEffectPackage
	if pkg == null:
		return
	for model in pkg.param_models:
		if model == null:
			continue
		model.change_params_sim(ctx)

	var effect: Variant = action_match.get("effect", null)
	if effect is NPCAttackSequence:
		action_panel_label.text = _format_attack_soul_stats(ctx, _summon_card_ap_bonus)
		action_panel_label.modulate = _stat_modulate_for_delta(_summon_card_ap_bonus, _default_action_panel_label_modulate)
		attack_icon.show()
		return

	if effect is NPCSummonSequence:
		action_panel_label.text = _format_summon_soul_stats(ctx, summon_data, _summon_card_ap_bonus, _summon_card_max_health_bonus)
		action_panel_label.modulate = _stat_modulate_for_delta(_summon_card_ap_bonus, _default_action_panel_label_modulate)
		summon_icon.show()

func _is_soul_stats_card(_card_data: CardData) -> bool:
	if _card_data == null:
		return false
	return int(_card_data.card_type) == int(CardData.CardType.SOULBOUND) \
		or int(_card_data.card_type) == int(CardData.CardType.SOULWILD)

func _find_preview_summon_data(_card_data: CardData) -> CombatantData:
	if _card_data == null:
		return null
	for action in _card_data.actions:
		if action is SummonAction:
			return (action as SummonAction).get_preview_summon_data()
	return null

func _find_first_soul_action_package(summon_data: CombatantData) -> Dictionary:
	if summon_data == null or summon_data.ai == null:
		return {}
	for action in summon_data.ai.actions:
		if action == null:
			continue
		for pkg in action.effect_packages:
			if pkg == null or pkg.effect == null:
				continue
			if pkg.effect is NPCAttackSequence or pkg.effect is NPCSummonSequence:
				return {
					"package": pkg,
					"effect": pkg.effect,
				}
	return {}

func _build_soul_preview_context(summon_data: CombatantData) -> NPCAIContext:
	var ctx := NPCAIContext.new()
	ctx.combatant_data = summon_data
	ctx.params = {}
	ctx.state = {}
	ctx.forecast = true
	return ctx

func _format_attack_soul_stats(ctx: NPCAIContext, ap_bonus: int = 0) -> String:
	if ctx == null:
		return "-"

	var damage := maxi(int(ctx.params.get(Keys.DAMAGE, 0)) + int(ap_bonus), 0)
	var strikes := maxi(int(ctx.params.get(Keys.STRIKES, 1)), 1)
	if strikes <= 1:
		return str(damage)
	return "%s×%s" % [strikes, damage]

func _format_summon_soul_stats(
	ctx: NPCAIContext,
	fallback_data: CombatantData,
	ap_bonus: int = 0,
	max_health_bonus: int = 0
) -> String:
	var summon_data := fallback_data
	if ctx != null:
		var ctx_summon_data: Variant = ctx.params.get(Keys.SUMMON_DATA, null)
		if ctx_summon_data is CombatantData:
			summon_data = ctx_summon_data

	if summon_data == null:
		return "-"

	return "%s|%s" % [
		maxi(int(summon_data.ap) + int(ap_bonus), 0),
		maxi(int(summon_data.max_health) + int(max_health_bonus), 0),
	]

func _stat_modulate_for_delta(delta: int, fallback: Color) -> Color:
	if int(delta) > 0:
		return POSITIVE_STAT_MOD_COLOR
	if int(delta) < 0:
		return NEGATIVE_STAT_MOD_COLOR
	return fallback

## card_visuals.gd
#
#class_name CardVisuals extends Control
#
#@onready var glow: Sprite2D = %Glow
#@onready var card_front: TextureRect = %CardFront
#@onready var cost_blue_sprites: AnimatedSprite2D = %CostBlue
#@onready var cost_red_sprites: AnimatedSprite2D = %CostRed
#@onready var cost_green_sprites: AnimatedSprite2D = %CostGreen
#@onready var cost_container: Sprite2D = %CostContainer
#@onready var name_label: Label = %NameLabel
#@onready var card_art_rect: TextureRect = %CardArtRect
#@onready var description: RichTextLabel = %Description
#@onready var rarity: TextureRect = %Rarity
#@onready var card_strictly_visuals: Node2D = $CardStrictlyVisuals
#@onready var cost_label: Label = $CardStrictlyVisuals/CornerMan/CostDisplay/CostLabel
#@onready var cost_display: Node2D = %CostDisplay
#
#@export var card_angle_limit_flt: float = 180
#@export var max_card_spread_angle_flt: float = 38
#
#const OVERLOAD_PIP := preload("uid://pe4lgl2dwu32")
#const OVERLOAD_1_COLOR := Color(1.0, 0.88, 0.22, 1.0)
#const OVERLOAD_2_COLOR := Color(1.0, 0.56, 0.12, 1.0)
#const OVERLOAD_3_COLOR := Color(0.9, 0.18, 0.18, 1.0)
#const OVERLOAD_4_PLUS_COLOR := Color(0.45, 0.06, 0.06, 1.0)
#
#@export var card_data: CardData : set = _set_card_data
#var cost_red: int = 0 : set = set_cost_red
#var cost_green: int = 0 : set = set_cost_green
#var cost_blue: int = 0 : set = set_cost_blue
#var overload: int = 0
#var _card_data_internal: CardData
#var mana_panel_radius: float
#var _default_cost_label_modulate: Color = Color.WHITE
#
#func _ready() -> void:
	#mana_panel_radius = cost_container.texture.get_size().y * cost_container.scale.y * 0.5-0.75
	#_default_cost_label_modulate = cost_label.modulate
	#refresh_from_card_data()
#
#func set_overload(amount: int) -> void:
	#overload = maxi(int(amount), 0)
	#for pip in _get_overload_pips():
		#pip.queue_free()
	#for _i in range(overload):
		#cost_display.add_child(OVERLOAD_PIP.instantiate())
	#reposition_overload_pips()
	#_refresh_cost_label_color()
#
#func _set_card_data(value: CardData) -> void:
	#assert(value != null, "CardVisuals received null CardData")
	#if !is_node_ready():
		#await ready
	#_card_data_internal = value
	#name_label.text = value.name
	#refresh_from_card_data()
	#card_art_rect.texture = value.texture
	#rarity.modulate = CardData.RARITY_COLORS[value.rarity]
#
#func refresh_from_card_data() -> void:
	#if !is_node_ready():
		#await ready
	#if _card_data_internal == null:
		#set_overload(0)
		#cost_label.text = "0"
		#cost_label.modulate = _default_cost_label_modulate
		#return
#
	#set_overload(int(_card_data_internal.overload))
	#set_total_cost()
#
#func set_description(new_description: String) -> void:
	#description.set_text(new_description)
#
#func set_total_cost() -> void:
	#if _card_data_internal == null:
		#return
	#cost_label.text = str(_card_data_internal.get_total_cost())
	#_refresh_cost_label_color()
	#
#
#func set_cost_red(cost: int) -> void:
	#cost_red = cost
	#match cost_red:
		#0:
			#cost_red_sprites.frame = 0
		#1:
			#cost_red_sprites.frame = 1
#
#func set_cost_green(cost: int) -> void:
	#cost_green = cost
	#match cost_green:
		#0:
			#cost_green_sprites.frame = 0
		#1:
			#cost_green_sprites.frame = 1
#
#func set_cost_blue(cost: int) -> void:
	#cost_blue = cost
	#match cost_blue:
		#0:
			#cost_blue_sprites.frame = 0
		#1:
			#cost_blue_sprites.frame = 1
#
#func _get_overload_pips() -> Array[OverloadPip]:
	#var pips: Array[OverloadPip] = []
	#for child in cost_display.get_children():
		#if child is OverloadPip:
			#pips.push_back(child)
	#return pips
#
#func reposition_overload_pips() -> void:
	#var pips := _get_overload_pips()
	#var pip_spread_angle_flt: float = 0
	#var current_pip_angle_flt: float = 0
	#var pip_angle_increment_flt: float = 0
#
	#if pips.size() >= 2:
		#pip_spread_angle_flt = min(card_angle_limit_flt, max_card_spread_angle_flt * (pips.size() - 1))
		#current_pip_angle_flt = -pip_spread_angle_flt / 2
		#pip_angle_increment_flt = pip_spread_angle_flt / (pips.size() - 1)
#
	#for pip in pips:
		#_update_pip_transform(pip, current_pip_angle_flt)
		#current_pip_angle_flt += pip_angle_increment_flt
#
#func get_pip_position(angle_deg_flt: float) -> Vector2:
	#var x: float = mana_panel_radius * cos(deg_to_rad(angle_deg_flt + 270))
	#var y: float = mana_panel_radius * sin(deg_to_rad(angle_deg_flt + 270))
	##print("overload: ", overload, " angle: ", angle_deg_flt, " x: ", x, " y: ", y)
	#return Vector2(x, y)#cost_display.position + Vector2(x, y)
#
#func _update_pip_transform(pip: OverloadPip, angle_in_drag: float) -> void:
	#var pos: Vector2 = get_pip_position(angle_in_drag)
	#pip.position = pos
#
#func _refresh_cost_label_color() -> void:
	#if cost_label == null:
		#return
#
	#match overload:
		#0:
			#cost_label.modulate = _default_cost_label_modulate
		#1:
			#cost_label.modulate = OVERLOAD_1_COLOR
		#2:
			#cost_label.modulate = OVERLOAD_2_COLOR
		#3:
			#cost_label.modulate = OVERLOAD_3_COLOR
		#_:
			#cost_label.modulate = OVERLOAD_4_PLUS_COLOR
