extends Node

# Signal to broadcast when loading is complete
signal all_characters_loaded

var total_characters_to_load = 0
var characters_loaded = 0

func register_character():
	total_characters_to_load += 1
	
func notify_character_ready():
	
	characters_loaded += 1
	print("characters loaded: %s, total to load: %s" % [characters_loaded, total_characters_to_load])
	if characters_loaded >= total_characters_to_load:
		print("all characters ready")
		# All characters are ready, emit the signal
		all_characters_loaded.emit()
