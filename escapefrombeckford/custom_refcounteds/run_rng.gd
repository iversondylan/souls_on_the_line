# run_rng.gd

class_name RunRNG extends RefCounted

var run_seed: int = 0
var streams: Dictionary = {} # label:String -> {"seed":int,"rolls":int}

func _init(_run_seed: int) -> void:
	run_seed = _run_seed

func get_stream(label: String) -> RNG:
	var st: Dictionary = streams.get(label, {})
	if st.is_empty():
		var s := RNGUtil.seed_from_label(run_seed, label)
		st = {"seed": s, "rolls": 0}
		streams[label] = st

	# IMPORTANT: return an RNG that writes back its rolls after use
	# simplest: return a “live view” wrapper:
	var rng := RNG.new(int(st["seed"]), int(st["rolls"]))
	# attach a small commit closure pattern (manual commit is simplest)
	rng.set_meta("label", label)
	rng.set_meta("owner", self)
	return rng

func commit(rng: RNG) -> void:
	if rng == null:
		return
	var label := String(rng.get_meta("label"))
	if label == "":
		return
	var st: Dictionary = streams.get(label, {})
	if st.is_empty():
		return
	st["rolls"] = rng.rolls
	streams[label] = st

func snapshot() -> Dictionary:
	return {"run_seed": run_seed, "streams": streams.duplicate(true)}

static func from_snapshot(d: Dictionary) -> RunRNG:
	var rr := RunRNG.new(int(d.get("run_seed", 0)))
	rr.streams = (d.get("streams", {}) as Dictionary).duplicate(true)
	return rr
