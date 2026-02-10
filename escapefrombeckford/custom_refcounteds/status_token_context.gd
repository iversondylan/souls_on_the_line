# status_token_context.gd

class_name StatusTokenContext extends RefCounted

var id: String = ""

var intensity : int = -1
var duration: int = -1

# Owner reference (either node or id, or both)
var owner: Node = null
var owner_id: int = -1
