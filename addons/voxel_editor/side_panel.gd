@tool
extends ScrollContainer
class_name SidePannel
const ColorButton = preload("color_button.tscn")

var color: Color = Color.WHITE_SMOKE

const palette = [
	"#1abc9c",
	"#e8f8f5",
	"#d1f2eb",
	"#a3e4d7",
	"#76d7c4",
	"#48c9b0",
	"#1abc9c",
	"#17a589",
	"#148f77",
	"#117864",
	"#0e6251",
	"#16a085",
	"#e8f6f3",
	"#d0ece7",
	"#a2d9ce",
	"#73c6b6",
	"#45b39d",
	"#16a085",
	"#138d75",
	"#117a65",
	"#0e6655",
	"#0b5345",
	"#2ecc71",
	"#eafaf1",
	"#d5f5e3",
	"#abebc6",
	"#82e0aa",
	"#58d68d",
	"#2ecc71",
	"#28b463",
	"#239b56",
	"#1d8348",
	"#186a3b",
	"#27ae60",
	"#e9f7ef",
	"#d4efdf",
	"#a9dfbf",
	"#7dcea0",
	"#52be80",
	"#27ae60",
	"#229954",
	"#1e8449",
	"#196f3d",
	"#145a32",
	"#3498db",
	"#ebf5fb",
	"#d6eaf8",
	"#aed6f1",
	"#85c1e9",
	"#5dade2",
	"#3498db",
	"#2e86c1",
	"#2874a6",
	"#21618c",
	"#1b4f72",
	"#2980b9",
	"#eaf2f8",
	"#d4e6f1",
	"#a9cce3",
	"#7fb3d5",
	"#5499c7",
	"#2980b9",
	"#2471a3",
	"#1f618d",
	"#1a5276",
	"#154360",
	"#9b59b6",
	"#f5eef8",
	"#ebdef0",
	"#d7bde2",
	"#c39bd3",
	"#af7ac5",
	"#9b59b6",
	"#884ea0",
	"#76448a",
	"#633974",
	"#512e5f",
	"#8e44ad",
	"#f4ecf7",
	"#e8daef",
	"#d2b4de",
	"#bb8fce",
	"#a569bd",
	"#8e44ad",
	"#7d3c98",
	"#6c3483",
	"#5b2c6f",
	"#4a235a",
	"#34495e",
	"#ebedef",
	"#d6dbdf",
	"#aeb6bf",
	"#85929e",
	"#5d6d7e",
	"#34495e",
	"#2e4053",
	"#283747",
	"#212f3c",
	"#1b2631",
	"#2c3e50",
	"#eaecee",
	"#d5d8dc",
	"#abb2b9",
	"#808b96",
	"#566573",
	"#2c3e50",
	"#273746",
	"#212f3d",
	"#1c2833",
	"#17202a",
	"#f1c40f",
	"#fef9e7",
	"#fcf3cf",
	"#f9e79f",
	"#f7dc6f",
	"#f4d03f",
	"#f1c40f",
	"#d4ac0d",
	"#b7950b",
	"#9a7d0a",
	"#7d6608",
	"#f39c12",
	"#fef5e7",
	"#fdebd0",
	"#fad7a0",
	"#f8c471",
	"#f5b041",
	"#f39c12",
	"#d68910",
	"#b9770e",
	"#9c640c",
	"#7e5109",
	"#e67e22",
	"#fdf2e9",
	"#fae5d3",
	"#f5cba7",
	"#f0b27a",
	"#eb984e",
	"#e67e22",
	"#ca6f1e",
	"#af601a",
	"#935116",
	"#784212",
	"#d35400",
	"#fbeee6",
	"#f6ddcc",
	"#edbb99",
	"#e59866",
	"#dc7633",
	"#d35400",
	"#ba4a00",
	"#a04000",
	"#873600",
	"#6e2c00",
	"#e74c3c",
	"#fdedec",
	"#fadbd8",
	"#f5b7b1",
	"#f1948a",
	"#ec7063",
	"#e74c3c",
	"#cb4335",
	"#b03a2e",
	"#943126",
	"#78281f",
	"#c0392b",
	"#f9ebea",
	"#f2d7d5",
	"#e6b0aa",
	"#d98880",
	"#cd6155",
	"#c0392b",
	"#a93226",
	"#922b21",
	"#7b241c",
	"#641e16",
	"#ecf0f1",
	"#fdfefe",
	"#fbfcfc",
	"#f7f9f9",
	"#f4f6f7",
	"#f0f3f4",
	"#ecf0f1",
	"#d0d3d4",
	"#b3b6b7",
	"#979a9a",
	"#7b7d7d",
	"#bdc3c7",
	"#f8f9f9",
	"#f2f3f4",
	"#e5e7e9",
	"#d7dbdd",
	"#cacfd2",
	"#bdc3c7",
	"#a6acaf",
	"#909497",
	"#797d7f",
	"#626567",
	"#95a5a6",
	"#f4f6f6",
	"#eaeded",
	"#d5dbdb",
	"#bfc9ca",
	"#aab7b8",
	"#95a5a6",
	"#839192",
	"#717d7e",
	"#5f6a6a",
	"#4d5656",
	"#7f8c8d",
	"#f2f4f4",
	"#e5e8e8",
	"#ccd1d1",
	"#b2babb",
	"#99a3a4",
	"#7f8c8d",
	"#707b7c",
	"#616a6b",
	"#515a5a",
	"#424949",
]


static func create_color_button(color: Color) -> Node:
	var button = ColorButton.instantiate()
	button.connect("color_picked", _on_color_picked)
	button.set_color(color)
	return button


func _ready():
	print_debug("Palette is ready")
	for code in palette:
		%PaletteGrid.add_child(create_color_button(Color(code)))
	# Assuming there is at least a color.
	%PaletteGrid.get_child(0)._pressed()


func is_new_recent_color(candidate: Color):
	for child in %RecentGrid.get_children():
		if child.get_color() == candidate:
			return false
	return true


func set_color(color: Color):
	_on_color_picked(color)


func _on_color_picked(picked_color: Color):
	const max_recent = 5
	print_debug("Color picked ", picked_color)
	if is_new_recent_color(picked_color):
		print("new")
		var new_color = create_color_button(Color(picked_color))
		var grid = %RecentGrid
		grid.add_child(new_color)
		grid.move_child(new_color, 0)
		if grid.get_child_count() > max_recent:
			var deleted = grid.get_child(max_recent)
			grid.remove_child(deleted)
			deleted.queue_free()
	color = picked_color


func _on_resized():
	# Adjust the number of columns according to the width.
	var w = %PaletteGrid.get_child(0).size.x + %PaletteGrid.get_theme_constant("h_separation")
	%PaletteGrid.columns = int(size.x / w)
	%RecentGrid.columns = int(size.x / w)


enum SymmetryMode { NO, XY_ODD, XY_EVEN }


func symmetry_mode() -> SymmetryMode:
	return %SymmetryCombo.selected


signal export_requested


func _on_export_pressed():
	emit_signal("export_requested")
