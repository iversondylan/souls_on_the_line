# battle_transport.gd
class_name BattleTransport extends RefCounted

var playback_scale: float = 1.0

# Later I add:
# func wait_beats(beats: float) -> void
# and in there I quantize against BPM + audio playback position

func wait_seconds(sec: float) -> void:
	if sec <= 0.0:
		return
	await Engine.get_main_loop().create_timer(sec * playback_scale).timeout

func wait_frames(n: int = 1) -> void:
	for _i in range(maxi(n, 1)):
		await Engine.get_main_loop().process_frame
