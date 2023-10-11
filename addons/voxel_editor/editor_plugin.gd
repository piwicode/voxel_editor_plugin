@tool
extends EditorPlugin

const VoxelNode = preload("voxel_node.gd")
const GizmoPlugin = preload("gizmo_plugin.gd")
var gizmo_plugin = GizmoPlugin.new()


func _enter_tree():
	print_debug()
	add_node_3d_gizmo_plugin(gizmo_plugin)
	add_custom_type("Voxel", "Node3D", VoxelNode, preload("icon.png"))
	set_input_event_forwarding_always_enabled()


func _exit_tree():
	print_debug()
	remove_node_3d_gizmo_plugin(gizmo_plugin)
	remove_custom_type("Voxel")
	# Stop pending interactions if any.
	should_handle = false


# True when the editor should process mouse input.
var should_handle = false


func _is_voxel_node(object):
	return object is VoxelNode


func _handles(object):
	should_handle = object is VoxelNode
	print("voxel editor plugin set should_handle to ", should_handle)
	return should_handle


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


static func mesh_id_bit(v: Vector3i):
	assert(v.x == 1 or v.x == -1)
	assert(v.y == 1 or v.y == -1)
	assert(v.z == 1 or v.z == -1)
	return 1 << ((v.x + 1) / 2 + (v.y + 1) / 2 * 2 + (v.z + 1) / 2 * 4)


func do_paint_cell_action(voxel_node, map_position: Vector3i, mesh_id: int):
	var previous_mesh_id = voxel_node.get_cell(map_position)
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Add cell")
	undo_redo.add_do_method(voxel_node, "set_cell", map_position, mesh_id)
	undo_redo.add_undo_method(voxel_node, "set_cell", map_position, previous_mesh_id)
	undo_redo.commit_action()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not should_handle:
		return AFTER_GUI_INPUT_PASS

	if event is InputEventMouse:
		var ray_origin = camera.project_ray_origin(event.position)
		var ray_end = ray_origin + camera.project_ray_normal(event.position) * camera.far
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		var result = camera.get_world_3d().direct_space_state.intersect_ray(query)

#		print("intersect ray result ", result)
		if not result:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		var cell_node = result.collider.get_parent_node_3d()
		var voxel_node = cell_node.get_parent_node_3d()

#		print("parent ", picked_cell.name, " ", picked_voxel.name, " ", picked_voxel is VoxelNode)
		if not voxel_node is VoxelNode:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		var local_normal = voxel_node.global_transform.basis.inverse() * result.normal
		var map_position = Vector3i(cell_node.position)
		var snapping = _snap_one_sub_element(result.position - cell_node.position)

#		print({map_position=map_position, local_normal=local_normal, new_box_position=new_box_position})
#		print(snapping)
		if gizmo_plugin.highlight(map_position, local_normal, snapping):
			voxel_node.update_gizmos()

		if not event is InputEventMouseButton:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if not event.pressed:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		if event.button_index == 1:
			match _enumerate_units(snapping):
				[var n]:  # Face, insert cube
					var new_box_position = map_position + n
					var undo_redo = get_undo_redo()
					var new_mesh_id = voxel_node.get_cell(map_position)
					print("current cell %x" % new_mesh_id)
					new_mesh_id &= FaceMask[-n]
					print("masked cell %x" % new_mesh_id)
					new_mesh_id |= new_mesh_id >> max(0, FaceShift[-n]) << max(0, -FaceShift[-n])
					print("new cell %x" % new_mesh_id)
					do_paint_cell_action(voxel_node, new_box_position, new_mesh_id)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				[var t, var u]:  # Edge
					if voxel_node.get_cell(map_position + snapping):
						if voxel_node.get_cell(map_position + t):
							var new_box_position = map_position + u
							var new_mesh_id = FaceMask[u] | FaceMask[-t]
							print(
								{
									t = t,
									u = u,
									fmu = FaceMask[-u],
									fmt = FaceMask[t],
									new_mesh_id = new_mesh_id
								}
							)
							do_paint_cell_action(voxel_node, new_box_position, new_mesh_id)
							return EditorPlugin.AFTER_GUI_INPUT_STOP
						elif voxel_node.get_cell(map_position + u):
							var new_box_position = map_position + t
							var new_mesh_id = FaceMask[t] | FaceMask[-u]
							print(
								{
									t = t,
									u = u,
									fmt = FaceMask[-t],
									fmu = FaceMask[u],
									new_mesh_id = new_mesh_id
								}
							)
							do_paint_cell_action(voxel_node, new_box_position, new_mesh_id)
							return EditorPlugin.AFTER_GUI_INPUT_STOP
				[var a, var b, var c]:
					print("Point")
					var inormal = Vector3i(local_normal.round())
					var edited_coord = map_position + inormal

					# Count how many axis the normal has.
					# Normal component are 0, sqr(1/3) sqr(1/2) 1
					if inormal.length_squared() == 1:
						var uv = _enumerate_units(snapping - inormal)
						var u = uv[0]
						var v = uv[1]
						print({u = u, v = v})
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
							do_paint_cell_action(voxel_node, edited_coord, new_mesh_id)
							return EditorPlugin.AFTER_GUI_INPUT_STOP

		elif event.button_index == 2:
			# Delete
			do_paint_cell_action(voxel_node, map_position, 0)
			gizmo_plugin.highlight(null, null, null)
			voxel_node.update_gizmos()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
#	elif event is InputKeyEvent:
#		if event.keycode == KEY_P:

	return EditorPlugin.AFTER_GUI_INPUT_PASS
