class_name HealthBar extends ProgressBar

@onready var timer: Timer = $Timer
@onready var damage_bar: ProgressBar = $DamageBar

var n_health := 0 : set = _set_health

func _set_health(new_health) -> void:
	var old_health := n_health
	n_health = min(max_value, new_health)
	value = n_health
	if n_health < old_health:
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT)
		tween.tween_property(damage_bar, "value", n_health, 0.5)
		#timer.start()
	else:
		damage_bar.value = n_health

func init_health(init_health: int) -> void:
	n_health = init_health
	max_value = n_health
	value = n_health
	damage_bar.max_value = n_health
	damage_bar.value = n_health
