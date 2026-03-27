@tool
extends EditorScript

func _run():
	var root := "res://"
	var lines: Array[String] = []
	_walk(root, 0, lines)

	var output := "\n".join(lines)
	print(output)

	# Optional: write to file
	var f := FileAccess.open("res://fs_tree.txt", FileAccess.WRITE)
	f.store_string(output)
	f.close()

func _walk(path: String, depth: int, lines: Array):
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue

		var full := path + "/" + name
		lines.append("%s%s" % ["  ".repeat(depth), name])

		if dir.current_is_dir():
			_walk(full, depth + 1, lines)

	dir.list_dir_end()
