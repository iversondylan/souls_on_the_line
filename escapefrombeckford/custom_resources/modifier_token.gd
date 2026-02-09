# modifier_token.gd
class_name ModifierToken extends RefCounted

enum Scope { GLOBAL, SELF, TARGET }

var type: Modifier.Type
var flat_value: int = 0
var mult_value: float = 0.0 #interpreted as 100% + mult_value*100%
var source_id: String
var owner: Node
var owner_id: int
var priority: int = 0



var scope: Scope = Scope.GLOBAL # The entity responsible for emitting this token
# The status holder for SELF tokens
# The aura source for aura-secondaries
# The battle scene or relic for GLOBAL tokens

# Semantic flags (optional)
var tags: Array[String] = []
