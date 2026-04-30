class_name HealthBar extends PanelContainer

@onready var health_bar: ProgressBar = %HealthBar
@onready var damage_bar: ProgressBar = %DamageBar
@onready var health_number: Label = %HealthNumber
@onready var max_health_number: Label = %MaxHealthNumber
@onready var bound_icon: TextureRect = $HBoxContainer/BoundIcon
@onready var wild_icon: TextureRect = $HBoxContainer/WildIcon
@onready var card_reserved_icon: TextureRect = $HBoxContainer/CardReservedIcon

@export var inside_control: bool = false
@export var font_size: int = 30 : set = _set_font_size, get = _get_font_size
@export var fit_width_to_contents: bool = false
@export var fixed_height: float = 0.0

var _font_size: int = 30

var health : int = 0 : set = _set_health
var max_health: int : set = _set_max_health
var damage_health: int : set = _set_damage_health

func _ready() -> void:
	_apply_font_size()
	update_status_icons(CombatantState.Mortality.MORTAL, false)
	_refresh_layout_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recenter_if_needed()

func update_health(combatant_data: CombatantData) -> void:
	max_health = combatant_data.max_health
	health = combatant_data.max_health

func update_health_view(_max_health: int, _health: int) -> void:
	max_health = _max_health
	health = _health
	_refresh_layout_deferred()

func update_status_icons(mortality: CombatantState.Mortality, has_summon_reserve_card: bool) -> void:
	var is_bound := int(mortality) == int(CombatantState.Mortality.BOUND)
	var is_wild := int(mortality) == int(CombatantState.Mortality.WILD)

	if bound_icon != null:
		bound_icon.visible = is_bound
	if wild_icon != null:
		wild_icon.visible = is_wild
	if card_reserved_icon != null:
		card_reserved_icon.visible = has_summon_reserve_card
	_refresh_layout_deferred()

func _set_max_health(new_health: int) -> void:
	max_health = new_health
	health_bar.max_value = max_health
	damage_bar.max_value = max_health

func _set_health(new_health) -> void:
	#var old_health := health
	health = min(health_bar.max_value, new_health)
	health_bar.value = health
	damage_health = health
	health_number.text = "%s" % health
	max_health_number.text = "/%s" % max_health

func _set_damage_health(new_health: int) -> void:
	damage_health = new_health
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT)
	tween.tween_property(damage_bar, "value", damage_health, 0.5)

func _set_font_size(new_size: int) -> void:
	_font_size = maxi(int(new_size), 1)
	if is_node_ready():
		_apply_font_size()
		_refresh_layout_deferred()

func _get_font_size() -> int:
	return _font_size

func _apply_font_size() -> void:
	var resolved_font_size := _get_font_size()
	health_number.add_theme_font_size_override("font_size", resolved_font_size)
	max_health_number.add_theme_font_size_override("font_size", resolved_font_size)

func _refresh_layout_deferred() -> void:
	if is_node_ready():
		call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if fit_width_to_contents:
		size.x = get_combined_minimum_size().x
	if fixed_height > 0.0:
		size.y = fixed_height
	_recenter_if_needed()

func _recenter_if_needed() -> void:
	if inside_control:
		return
	position.x = -0.5 * size.x
