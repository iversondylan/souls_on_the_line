class_name HealthBar extends ProgressBar

@onready var damage_bar: ProgressBar = $DamageBar
@onready var health_number: Label = $HealthNumber

var n_health : int = 0 : set = _set_health
var max_health: int
var damage_health: int : set = _set_damage_health
var damage_max_health: int : set = _set_damage_max_health

func _set_damage_health(new_health: int) -> void:
	damage_health = new_health
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT)
	tween.tween_property(damage_bar, "value", damage_health, 0.5)

func _set_damage_max_health(new_health: int) -> void:
	damage_max_health = new_health
	damage_bar.max_value = damage_max_health

func _set_health(new_health) -> void:
	var old_health := n_health
	n_health = min(max_value, new_health)
	value = n_health
	damage_health = n_health
	health_number.text = "%s/%s" % [n_health, max_health]

func init_health(init_health: int) -> void:
	#print("init_health is %s" % init_health)
	n_health = init_health
	max_health = n_health
	max_value = n_health
	value = n_health
	damage_max_health = max_health
	damage_health = max_health
	#print("damage bar max %s value %s" % [damage_bar.max_value, damage_bar.value])
	health_number.text = "%s/%s" % [n_health, max_health]
