class_name TooltipRequest extends RefCounted

enum PreferredSide {
	BELOW,
	ABOVE,
}

var anchor_control: Control = null
var anchor_rect: Rect2 = Rect2()
var icon_uid: String = ""
var text_bbcode: String = ""
var preferred_side: PreferredSide = PreferredSide.BELOW
var offset: Vector2 = Vector2.ZERO
var priority: int = 0
