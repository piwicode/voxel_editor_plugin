@tool
extends EditorPlugin

const Palette = preload("side_panel.tscn")
const VoxelNode = preload("voxel_node.gd")
const GizmoPlugin = preload("gizmo_plugin.gd")

const FaceMask = {
	Vector3i(1, 0, 0): 0xAA,
	Vector3i(0, 1, 0): 0xCC,
	Vector3i(0, 0, 1): 0xF0,
	Vector3i(-1, 0, 0): 0x55,
	Vector3i(0, -1, 0): 0x33,
	Vector3i(0, 0, -1): 0x0F
}

const FaceShift = {
	Vector3i(1, 0, 0): 1,
	Vector3i(0, 1, 0): 2,
	Vector3i(0, 0, 1): 4,
	Vector3i(-1, 0, 0): -1,
	Vector3i(0, -1, 0): -2,
	Vector3i(0, 0, -1): -4
}

var gizmo_plugin: GizmoPlugin
var palette: Control

var last_voxel_node = null
var last_map_position = null
var edited_voxel: VoxelNode = null


## Transforms intra-cell coordinates ([-.5, .5]³) into a snapped vector
## ({-1, 0, 1}³) pointing at the clicked primitive.
## The number of non null component depend on the typf of primitive:
## 0 is an inner face, 1 is a cube face, 2 is a cube edge, 3 is a cube corner.
static func _snap_one_sub_element(cell_local_pick: Vector3) -> Vector3i:
	const snap_size = .15
	# Assuming a pick on a cell from with coordinates from [-.5,.5]
	return Vector3i(cell_local_pick * 2 * (1.0 + snap_size))


## Decomposes a vector into an array of non zero axis aligned components.
static func _enumerate_units(v: Vector3i) -> Array:
	var result = []
	if v.x:
		result.append(Vector3i(v.x, 0, 0))
	if v.y:
		result.append(Vector3i(0, v.y, 0))
	if v.z:
		result.append(Vector3i(0, 0, v.z))
	return result


static func mesh_id_bit(v: Vector3i):
	assert(v.x == 1 or v.x == -1)
	assert(v.y == 1 or v.y == -1)
	assert(v.z == 1 or v.z == -1)
	return 1 << ((v.x + 1) / 2 + (v.y + 1) / 2 * 2 + (v.z + 1) / 2 * 4)


func _on_export_requested():
	if edited_voxel:
		edited_voxel.export_mesh()


func _enter_tree():
	palette = Palette.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, palette)
	palette.connect("export_requested", _on_export_requested)
	gizmo_plugin = GizmoPlugin.new()
	add_node_3d_gizmo_plugin(gizmo_plugin)

	add_custom_type("Voxel", "Node3D", VoxelNode, preload("icon.png"))
	set_input_event_forwarding_always_enabled()


func _exit_tree():
	remove_control_from_docks(palette)
	palette.queue_free()

	remove_node_3d_gizmo_plugin(gizmo_plugin)
	gizmo_plugin.queue_free()

	remove_custom_type("Voxel")

	# Stop any pending edition.
	edited_voxel = null


func _make_visible(visible: bool):
	print("EditorPlugin make_visible ", visible)


func _handles(object: Object):
	# Object can be a VoxelNode, a MultiNodeEdit or any selectable type.
	return object is VoxelNode


func _edit(object: Object):
	assert(object == null or object is VoxelNode)
	var previous_edited = edited_voxel
	edited_voxel = object
	if previous_edited != edited_voxel:
		gizmo_plugin.clear_highlight()
	print("EditorPlugin edit ", object)


func do_paint_cell_action(voxel_node, map_position: Vector3i, mesh_id: int, color: Color):
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Add cell")
	undo_redo.add_do_method(voxel_node, "set_cell", map_position, mesh_id, color)
	undo_redo.add_undo_method(
		voxel_node,
		"set_cell",
		map_position,
		voxel_node.get_cell(map_position),
		voxel_node.get_cell_color(map_position)
	)
	# Avoid doing twice the job for odd symetry when z = 0.
	if palette.symmetry_mode() == 2 or (palette.symmetry_mode() == 1 and map_position.z != 0):
		map_position.z = palette.symmetry_mode() - 1 - map_position.z
		undo_redo.add_do_method(voxel_node, "set_cell", map_position, mesh_id, color)
		undo_redo.add_undo_method(
			voxel_node,
			"set_cell",
			map_position,
			voxel_node.get_cell(map_position),
			voxel_node.get_cell_color(map_position)
		)

	undo_redo.commit_action()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if edited_voxel == null:
		return AFTER_GUI_INPUT_PASS

	if event is InputEventKey:
		if event.keycode == KEY_E and event.echo == false:
			edited_voxel.export_mesh()
		if event.keycode == KEY_P and event.echo == false:
			if event.shift_pressed:
				# Pick color.
				palette.set_color(last_voxel_node.get_cell_color(last_map_position))
			else:
				# Apply color
				do_paint_cell_action(
					last_voxel_node,
					last_map_position,
					last_voxel_node.get_cell(last_map_position),
					palette.color
				)
				print("paint")

	if event is InputEventMouse:
		var ray_origin = camera.project_ray_origin(event.position)
		var ray_end = ray_origin + camera.project_ray_normal(event.position) * camera.far
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		var result = camera.get_world_3d().direct_space_state.intersect_ray(query)

		if not result:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		var cell_node = result.collider.get_parent_node_3d()
		var voxel_node = cell_node.get_parent_node_3d()

		if not voxel_node is VoxelNode:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		var global_to_map_coord = voxel_node.global_transform.affine_inverse()
		var local_normal = (global_to_map_coord.basis * result.normal).normalized()

		var map_position = Vector3i(cell_node.position)
		var snapping = _snap_one_sub_element(
			global_to_map_coord * result.position - cell_node.position
		)

		last_voxel_node = voxel_node
		last_map_position = map_position
		gizmo_plugin.highlight(voxel_node, map_position, result.normal, snapping)

		if not event is InputEventMouseButton:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if not event.pressed:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		if event.button_index == 1:
			match _enumerate_units(snapping):
				[]:  # Inner face
					# Triangle cylinder is turned into a cube.
					do_paint_cell_action(
						voxel_node,
						map_position,
						voxel_node.CUBE,
						voxel_node.get_cell_color(map_position)
					)
				[var n]:  # Face, insert cube
					var new_box_position = map_position + n
					var undo_redo = get_undo_redo()
					var new_mesh_id = voxel_node.get_cell(map_position)
					print("current cell %x" % new_mesh_id)
					new_mesh_id &= FaceMask[-n]
					print("masked cell %x" % new_mesh_id)
					new_mesh_id |= new_mesh_id >> max(0, FaceShift[-n]) << max(0, -FaceShift[-n])
					print("new cell %x" % new_mesh_id)
					do_paint_cell_action(voxel_node, new_box_position, new_mesh_id, palette.color)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				[var t, var u]:  # Edge
					if voxel_node.get_cell(map_position + snapping):
						# Attempt attempt to insert a triangle base cylinder.
						#
						# +---+  pick ray
						# | A |↙
						# +---o---+
						#     | B |
						#     +---+
						# o is the clicked edge.
						# snapping is ↘ or ↖ depending on which cell was picked.
						# We have to figure out which side has been picked.
						var snapping_ortho: Vector3i = t - u
						var local_pick_dir = global_to_map_coord.basis * (ray_end - ray_origin)
						var pick_sign = int(signf(local_pick_dir.dot(Vector3(snapping_ortho))))

						assert(pick_sign != 0., "edge should not be visible. please report.")
						var new_cell_rel_pos = Vector3i(snapping - snapping_ortho * pick_sign) / 2
						assert(new_cell_rel_pos == t or new_cell_rel_pos == u)
						var new_cell_position = map_position + new_cell_rel_pos
						assert(
							voxel_node.get_cell(new_cell_position) == 0,
							"cell should be empty. please report."
						)
						var new_mesh_id = (
							FaceMask[-new_cell_rel_pos] | FaceMask[snapping - new_cell_rel_pos]
						)
						do_paint_cell_action(
							voxel_node, new_cell_position, new_mesh_id, palette.color
						)
						return EditorPlugin.AFTER_GUI_INPUT_STOP

				[var a, var b, var c]:  # Point.
					var inormal = Vector3i(local_normal.round())
					var edited_coord = map_position + inormal

					# Count how many axis the normal has.
					# Normal component are 0, sqr(1/3), sqr(1/2), 1, all being
					# in [0.5, 1.0] and {0.0, 1.0} once rounded.
					if inormal.length_squared() == 1:
						var uv = _enumerate_units(snapping - inormal)
						var u = uv[0]
						var v = uv[1]

						if (
							voxel_node.get_cell(edited_coord + u)
							and voxel_node.get_cell(map_position + v)
						):
							var new_mesh_id = (
								mesh_id_bit(snapping)
								| mesh_id_bit(snapping - inormal * 2)
								| mesh_id_bit(snapping - inormal * 2 - u * 2)
								| mesh_id_bit(snapping - inormal * 2 - v * 2)
							)
							do_paint_cell_action(
								voxel_node, edited_coord, new_mesh_id, palette.color
							)
							return EditorPlugin.AFTER_GUI_INPUT_STOP

		elif event.button_index == 2:
			print("bt2")
			match _enumerate_units(snapping):
				[]:  # Inner face => Delete the cell.
					do_paint_cell_action(voxel_node, map_position, 0, palette.color)
					gizmo_plugin.clear_highlight()
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				[_]:  # Box face => Delete the cell.
					do_paint_cell_action(voxel_node, map_position, 0, palette.color)
					gizmo_plugin.clear_highlight()
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				[var t, var u]:  # Box edge => Attempt to turn into a triangle cylinder.
					if (
						voxel_node.get_cell(map_position) == voxel_node.CUBE
						and voxel_node.get_cell(map_position + t) == 0
						and voxel_node.get_cell(map_position + u) == 0
						and voxel_node.get_cell(map_position + t + u) == 0
					):
						do_paint_cell_action(
							voxel_node,
							map_position,
							FaceMask[-t] | FaceMask[-u],
							voxel_node.get_cell_color(map_position)
						)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				[var t, var u, var v]:
					if voxel_node.get_cell(map_position) == voxel_node.CUBE:
						#						and voxel_node.get_cell(map_position + t) == 0
						#						and voxel_node.get_cell(map_position + u) == 0
						#						and voxel_node.get_cell(map_position + v) == 0
						#						and voxel_node.get_cell(map_position + t + u + v) == 0
						do_paint_cell_action(
							voxel_node,
							map_position,
							FaceMask[-t] | FaceMask[-u] | FaceMask[-v],
							voxel_node.get_cell_color(map_position)
						)

		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	return EditorPlugin.AFTER_GUI_INPUT_PASS
