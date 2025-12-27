# res://utils/TextUtils.gd
class_name TextUtils

static func count_placeholders(text: String) -> int:
	return text.count("%s")

static func has_placeholders(text: String) -> bool:
	return text.contains("%s")

static func percent_to_symbol(text: String) -> String:
	return text.replace("percent", "%")
