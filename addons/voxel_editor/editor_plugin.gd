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


func _snap_one_sub_element(cell_local_pick: Vector3) -> Vector3i:
	var snap_size = .15
	# Assuming a pick on a cell from with coordinates from [-.5,.5]
	return Vector3i(cell_local_pick * 2 * (1.0 + snap_size))
	
func _forward_3d_gui_input(camera: Camera3D, event: InputEvent)-> int:
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
	
		var picked_cell = result.collider.get_parent_node_3d()
		var picked_voxel = picked_cell.get_parent_node_3d()

#		print("parent ", picked_cell.name, " ", picked_voxel.name, " ", picked_voxel is VoxelNode)
		if not picked_voxel is VoxelNode:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		
		var local_normal = picked_voxel.global_transform.basis.inverse() * result.normal 
		var map_position = Vector3i(picked_cell.position)
		var snapping = _snap_one_sub_element(result.position - picked_cell.position)
		var new_box_position = map_position + Vector3i(local_normal.round())

#		print({map_position=map_position, local_normal=local_normal, new_box_position=new_box_position})
#		print(snapping)
		if gizmo_plugin.highlight(map_position, local_normal, snapping):
			picked_voxel.update_gizmos()
		
		if not event is InputEventMouseButton:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if not event.pressed:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		if  event.button_index == 1:
			print(event)
			var undo_redo = get_undo_redo()
			undo_redo.create_action("Add cell")
			undo_redo.add_do_method(picked_voxel, "set_cell", new_box_position, 255)
			undo_redo.add_undo_method(picked_voxel, "set_cell", new_box_position, 0)
			undo_redo.commit_action()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif event.button_index == 2:
			var undo_redo = get_undo_redo()
			undo_redo.create_action("Remove cell")
			undo_redo.add_do_method(picked_voxel, "set_cell", map_position, 0)
			undo_redo.add_undo_method(picked_voxel, "set_cell", map_position, 255)
			undo_redo.commit_action()
			gizmo_plugin.highlight(null, null, null)
			picked_voxel.update_gizmos()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
#	elif event is InputKeyEvent:
#		if event.keycode == KEY_P:
			
	return EditorPlugin.AFTER_GUI_INPUT_PASS
