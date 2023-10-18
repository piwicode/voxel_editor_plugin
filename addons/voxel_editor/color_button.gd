@tool
extends Button

signal color_picked(color)


func get_color() -> Color:
	return $ColorRect.color


func set_color(color: Color):
	$ColorRect.color = color


func _pressed():
	emit_signal("color_picked", $ColorRect.color)
