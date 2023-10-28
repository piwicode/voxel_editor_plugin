@tool
class_name Event


static func LeftPress(event):
	return (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	)


static func LeftRelease(event):
	return (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	)


static func RightRelease(event):
	return (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	)


static func LeftButton(event):
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
