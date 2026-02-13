# sound.gd

class_name Sound extends Resource

@export var stream: AudioStream

@export_group("Base Mix")
@export_range(-40, 10) var volume_db := 0.0
@export_range(0.5, 2.0) var pitch := 1.0

@export_group("Variation")
@export var pitch_random := 0.0     # ± range
@export var volume_random := 0.0    # ± range
