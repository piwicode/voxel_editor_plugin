@tool
class_name VoxelEditor
extends EditorPlugin

const Palette = preload("side_panel.tscn")

var gizmo_plugin: GizmoPlugin
var palette: Control

var voxel: VoxelNode = null
var current_tool: Tool = PaintTool.new()

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


func _on_export_requested():
	if voxel:
		voxel.export_mesh()


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

	remove_custom_type("Voxel")

	# Stop any pending edition.
	voxel = null


func _make_visible(visible: bool):
	print("EditorPlugin make_visible ", visible)


func _handles(object: Object):
	# Object can be a VoxelNode, a MultiNodeEdit or any selectable type.
	return object is VoxelNode


func _edit(object: Object):
	assert(object == null or object is VoxelNode)
	var previous_edited = voxel
	voxel = object
	if previous_edited != voxel:
		gizmo_plugin.clear()
	print("EditorPlugin edit ", object)


func do_paint_cell_action(voxel_node, coord: Vector3i, mesh_id: int, color: Color):
	do_paint_volume_action(voxel_node, AABB(coord, Vector3.ZERO), mesh_id, color)


func do_paint_volume_action(voxel_node, aabb: AABB, mesh_id: int, color: Color):
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Add cell")
	for x in range(aabb.position.x, aabb.position.x + aabb.size.x + 1):
		for y in range(aabb.position.y, aabb.position.y + aabb.size.y + 1):
			for z in range(aabb.position.z, aabb.position.z + aabb.size.z + 1):
				var map_position = Vector3i(x, y, z)
				undo_redo.add_do_method(voxel_node, "set_cell", map_position, mesh_id, color)
				undo_redo.add_undo_method(
					voxel_node,
					"set_cell",
					map_position,
					voxel_node.get_cell(map_position),
					voxel_node.get_cell_color(map_position)
				)
	undo_redo.commit_action()


class Tool:
	enum { PASS_EVENT, CONSUME_EVENT, QUIT }

	static func __inresect_pick_ray(camera: Camera3D, event: InputEventMouse) -> Dictionary:
		var origin = camera.project_ray_origin(event.position)
		var end = origin + camera.project_ray_normal(event.position) * camera.far
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.collide_with_areas = true
		return {
			origin = origin,
			end = end,
			result = camera.get_world_3d().direct_space_state.intersect_ray(query)
		}


class VolumeCreationTool:
	extends Tool

	enum State { LURK, DEFINING_SURFACE, DEFINIG_VOLUME }

	var first_click_normal: Vector3i
	var click_coords = [null, null, null]
	var state: State = State.LURK
	var plane = Plane(Vector3.UP, -.49)

	func aabb() -> AABB:
		var aabb = AABB(click_coords[0].round(), Vector3.ZERO)
		for v in click_coords:
			if v != null:
				aabb = aabb.expand(v.round())
		return aabb

	func on_input(editor: EditorPlugin, camera: Camera3D, event: InputEvent) -> int:
		if event is InputEventKey:
			if event.keycode == KEY_ESCAPE:
				return QUIT
		elif event is InputEventMouse:
			on_mouse_input(editor, camera, event)
			if Event.LeftButton(event):
				return CONSUME_EVENT
		return PASS_EVENT

	func on_mouse_input(editor: EditorPlugin, camera: Camera3D, event: InputEventMouse):
		match state:
			State.LURK:
				var wpick = __inresect_pick_ray(camera, event)

				if wpick.result:
					first_click_normal = wpick.result.normal
					click_coords[0] = wpick.result.position + wpick.result.normal * 0.01
				else:
					var pick = Plane(Vector3.UP, -.49).intersects_ray(
						camera.project_ray_origin(event.position),
						camera.project_ray_normal(event.position)
					)
					if pick == null:
						return
					first_click_normal = plane.normal
					click_coords[0] = pick

				editor.gizmo_plugin.debug_point = click_coords[0]
				editor.gizmo_plugin.draw_volume(editor.voxel, aabb())
				if not Event.LeftPress(event):
					return
				plane = Plane(click_coords[0], first_click_normal)
				state = State.DEFINING_SURFACE

			State.DEFINING_SURFACE:
				var picked_point = plane.intersects_ray(
					camera.project_ray_origin(event.position),
					camera.project_ray_normal(event.position)
				)
				if picked_point == null:
					return
				click_coords[1] = picked_point
				editor.gizmo_plugin.debug_point = picked_point
				editor.gizmo_plugin.draw_volume(editor.voxel, aabb())
				if Event.LeftRelease(event):
					state = State.DEFINIG_VOLUME
			State.DEFINIG_VOLUME:
				var approach = Math.line_intersection(
					click_coords[1],
					first_click_normal,
					camera.project_ray_origin(event.position),
					camera.project_ray_normal(event.position)
				)
				click_coords[2] = approach
				editor.gizmo_plugin.draw_volume(editor.voxel, aabb())
				editor.gizmo_plugin.debug_point = approach
				if Event.LeftRelease(event):
					editor.do_paint_volume_action(
						editor.voxel, aabb(), VoxelNode.CUBE, editor.palette.color
					)
					return QUIT
				elif Event.RightRelease(event):
					editor.do_paint_volume_action(editor.voxel, aabb, 0, editor.palette.color)
					return QUIT


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if voxel == null:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_V and event.echo == false:
			current_tool = VolumeCreationTool.new()
	var r = current_tool.on_input(self, camera, event)
	if r == VolumeCreationTool.QUIT:
		print("Tool quit")
		voxel.clear_gizmos()
		current_tool = PaintTool.new()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	elif r == VolumeCreationTool.CONSUME_EVENT:
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS


class PaintTool:
	extends Tool
	var last_map_position = null

	func on_input(editor: VoxelEditor, camera: Camera3D, event: InputEvent) -> int:
		if event is InputEventKey:
			if event.pressed and event.keycode == KEY_E and event.echo == false:
				editor.voxel.export_mesh()
			if event.pressed and event.keycode == KEY_P and event.echo == false:
				if event.shift_pressed:
					# Pick color.
					editor.palette.set_color(editor.voxel.get_cell_color(last_map_position))
				else:
					# Apply color
					editor.do_paint_cell_action(
						editor.voxel,
						last_map_position,
						editor.voxel.get_cell(last_map_position),
						editor.palette.color
					)
					print("paint")

		if event is InputEventMouse:
			var pick = __inresect_pick_ray(camera, event)
			if not pick.result:
				return PASS_EVENT

			var cell_node = pick.result.collider.get_parent_node_3d()
			var voxel_node = cell_node.get_parent_node_3d()

			if not voxel_node is VoxelNode:
				return PASS_EVENT

			var global_to_map_coord = voxel_node.global_transform.affine_inverse()
			var local_normal = (global_to_map_coord.basis * pick.result.normal).normalized()

			var map_position = Vector3i(cell_node.position)
			var snapping = Math.snap_one_sub_element(
				global_to_map_coord * pick.result.position - cell_node.position
			)

			last_map_position = map_position
			editor.gizmo_plugin.highlight(voxel_node, map_position, pick.result.normal, snapping)

			if not event is InputEventMouseButton:
				return PASS_EVENT
			if not event.pressed:
				return PASS_EVENT

			if event.button_index == 1:
				match Math.enumerate_units(snapping):
					[]:  # Inner face
						# Triangle cylinder is turned into a cube.
						editor.do_paint_cell_action(
							voxel_node,
							map_position,
							voxel_node.CUBE,
							voxel_node.get_cell_color(map_position)
						)
					[var n]:  # Face, insert cube
						var new_box_position = map_position + n
						var new_mesh_id = voxel_node.get_cell(map_position)
						print("current cell %x" % new_mesh_id)
						new_mesh_id &= FaceMask[-n]
						print("masked cell %x" % new_mesh_id)
						new_mesh_id |= (
							new_mesh_id >> max(0, FaceShift[-n]) << max(0, -FaceShift[-n])
						)
						print("new cell %x" % new_mesh_id)
						editor.do_paint_cell_action(
							voxel_node, new_box_position, new_mesh_id, editor.palette.color
						)
						return CONSUME_EVENT
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
							var local_pick_dir = (
								global_to_map_coord.basis * (pick.end - pick.origin)
							)
							var pick_sign = int(signf(local_pick_dir.dot(Vector3(snapping_ortho))))

							assert(pick_sign != 0., "edge should not be visible. please report.")
							var new_cell_rel_pos = (
								Vector3i(snapping - snapping_ortho * pick_sign) / 2
							)
							assert(new_cell_rel_pos == t or new_cell_rel_pos == u)
							var new_cell_position = map_position + new_cell_rel_pos
							assert(
								voxel_node.get_cell(new_cell_position) == 0,
								"cell should be empty. please report."
							)
							var new_mesh_id = (
								FaceMask[-new_cell_rel_pos] | FaceMask[snapping - new_cell_rel_pos]
							)
							editor.do_paint_cell_action(
								voxel_node, new_cell_position, new_mesh_id, editor.palette.color
							)
							return CONSUME_EVENT

					[var a, var b, var c]:  # Point.
						var inormal = Vector3i(local_normal.round())
						var edited_coord = map_position + inormal

						# Count how many axis the normal has.
						# Normal component are 0, sqr(1/3), sqr(1/2), 1, all being
						# in [0.5, 1.0] and {0.0, 1.0} once rounded.
						if inormal.length_squared() == 1:
							var uv = Math.enumerate_units(snapping - inormal)
							var u = uv[0]
							var v = uv[1]

							if (
								voxel_node.get_cell(edited_coord + u)
								and voxel_node.get_cell(map_position + v)
							):
								var new_mesh_id = (
									Math.mesh_id_bit(snapping)
									| Math.mesh_id_bit(snapping - inormal * 2)
									| Math.mesh_id_bit(snapping - inormal * 2 - u * 2)
									| Math.mesh_id_bit(snapping - inormal * 2 - v * 2)
								)
								editor.do_paint_cell_action(
									voxel_node, edited_coord, new_mesh_id, editor.palette.color
								)
								return CONSUME_EVENT

			elif event.button_index == 2:
				print("bt2")
				match Math.enumerate_units(snapping):
					[]:  # Inner face => Delete the cell.
						editor.do_paint_cell_action(
							voxel_node, map_position, 0, editor.palette.color
						)
						editor.gizmo_plugin.clear()
						return CONSUME_EVENT
					[_]:  # Box face => Delete the cell.
						editor.do_paint_cell_action(
							voxel_node, map_position, 0, editor.palette.color
						)
						editor.gizmo_plugin.clear()
						return CONSUME_EVENT
					[var t, var u]:  # Box edge => Attempt to turn into a triangle cylinder.
						if (
							voxel_node.get_cell(map_position) == voxel_node.CUBE
							and voxel_node.get_cell(map_position + t) == 0
							and voxel_node.get_cell(map_position + u) == 0
							and voxel_node.get_cell(map_position + t + u) == 0
						):
							editor.do_paint_cell_action(
								voxel_node,
								map_position,
								FaceMask[-t] | FaceMask[-u],
								voxel_node.get_cell_color(map_position)
							)
						return CONSUME_EVENT
					[var t, var u, var v]:
						if voxel_node.get_cell(map_position) == voxel_node.CUBE:
							#	and voxel_node.get_cell(map_position + t) == 0
							#	and voxel_node.get_cell(map_position + u) == 0
							#	and voxel_node.get_cell(map_position + v) == 0
							#	and voxel_node.get_cell(map_position + t + u + v) == 0
							editor.do_paint_cell_action(
								voxel_node,
								map_position,
								FaceMask[-t] | FaceMask[-u] | FaceMask[-v],
								voxel_node.get_cell_color(map_position)
							)
			else:
				return PASS_EVENT

		return PASS_EVENT
