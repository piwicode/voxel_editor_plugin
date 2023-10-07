@tool
extends EditorPlugin

const VOXEL_SCRIPT = preload("voxel_node.gd")

var handles
func _enter_tree():
	print_debug()
	add_custom_type("Voxel", "Node3D", VOXEL_SCRIPT, preload("icon.png"))
	set_input_event_forwarding_always_enabled()

func _exit_tree():
	print_debug()
	should_handle = false
	remove_custom_type("Voxel")

var should_handle = false

func _is_voxel_node(object):
	return object.get_script() == VOXEL_SCRIPT

func _handles(object):
	should_handle = _is_voxel_node(object)
	print("set should_handle to ", should_handle)
	return should_handle

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent)-> int:
	if not should_handle:
		return AFTER_GUI_INPUT_PASS
	
	if event is InputEventMouseButton:
		if not event.pressed:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if not event.button_index == 1:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		print(event)
		
		var ray_origin = camera.project_ray_origin(event.position)
		var ray_end = ray_origin + camera.project_ray_normal(event.position) * camera.far
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		var result = camera.get_world_3d().direct_space_state.intersect_ray(query)
		
		print("intersect ray result ", result)
		if not result:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
		var picked_cell = result.collider.get_parent_node_3d().get_parent_node_3d()
		var picked_voxel = picked_cell.get_parent_node_3d()
		print("parent ", picked_voxel)
		if not _is_voxel_node(picked_voxel):
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		
		var local_normal = picked_voxel.global_transform.basis.inverse() * result.normal 
		var map_position = Vector3i(picked_cell.position)
		var new_box_position = map_position + Vector3i(local_normal.round())
		print({map_position=map_position, local_normal=local_normal, new_box_position=new_box_position})
		var undo_redo = get_undo_redo()
		undo_redo.create_action("Add cell")
		undo_redo.add_do_method(picked_voxel, "set_cell", new_box_position, 1)
		undo_redo.add_undo_method(picked_voxel, "set_cell", new_box_position, 0)
		undo_redo.commit_action()
	else:
		pass
	return EditorPlugin.AFTER_GUI_INPUT_STOP
