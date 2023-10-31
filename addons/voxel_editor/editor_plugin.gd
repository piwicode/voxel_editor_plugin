@tool
class_name VoxelEditor
extends EditorPlugin

const Palette = preload("side_panel.tscn")

var gizmo_plugin: GizmoPlugin
var palette: Control

var voxel: VoxelNode = null
var current_tool: Tool = PaintTool.new() :
	set(value):
		current_tool = value
		print("Start: ", value.name())


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
	enum { FACES = 1, EDGES = 2 , VERTICES = 3 }

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


	## Transforms intra-cell coordinates ([-.5, .5]³) into a snapped vector
	## ({-1, 0, 1}³) pointing at the clicked primitive.
	## The number of non null component depend on the typf of primitive:
	## 0 is an inner face, 1 is a cube face, 2 is a cube edge, 3 is a cube corner.
	static func __snap_one_sub_element(cell_local_pick: Vector3, 
			local_normal: Vector3,
			primitive_mask: int) -> Vector3i:
		if primitive_mask == FACES:
			# Assuming normal components are {√½, √⅓, 1}
			# Multiply by a factor so that inner face return Vector.ZERO
			return (local_normal * .7).round()
		assert(primitive_mask==7)
		const snap_size = .2
		# Assuming a pick on a cell from with coordinates from [-.5,.5]
		return Vector3i(cell_local_pick * 2 * (1.0 + snap_size))


	static func __try_pick_with_highlight(editor: EditorPlugin, camera: Camera3D, event: InputEvent, primitive_mask: int) -> Variant:
		var pick = __inresect_pick_ray(camera, event)
		if not pick.result:
			return null

		var cell_node = pick.result.collider.get_parent_node_3d()
		pick.voxel_node = cell_node.get_parent_node_3d()

		if not pick.voxel_node is VoxelNode:
			return null

		var global_to_map_coord = pick.voxel_node.global_transform.affine_inverse()
		pick.local_normal = (global_to_map_coord.basis * pick.result.normal).normalized()
		pick.coord = Vector3i(cell_node.position.round())

		pick.snapping = __snap_one_sub_element(
				global_to_map_coord * pick.result.position - cell_node.position,
				pick.local_normal,
				primitive_mask
			)
		var coords : Array[Vector3i] = [pick.coord]
		editor.gizmo_plugin.highlight(pick.voxel_node, coords, pick.result.normal, pick.snapping)
		return pick

	func name() -> String:
		return "Abstract tool"

	func on_input(editor: VoxelEditor, camera: Camera3D, event: InputEvent) -> int:
		return PASS_EVENT


class FaceGraph:
	extends Graphs.CellGraph
	var voxel: VoxelNode
	var neighbour_directions: Array[Vector3i] = []
	var normal: Vector3i
	func _init(voxel: VoxelNode, normal:Vector3i):
		self.neighbour_directions = [
			Vector3i(normal.y, normal.z, normal.x),
			Vector3i(normal.z, normal.x, normal.y),
			-Vector3i(normal.y, normal.z, normal.x),
			-Vector3i(normal.z, normal.x, normal.y)]
		self.voxel = voxel
		self.normal = normal

	func adjacent(v : Vector3i, neighbours: PackedVector3Array):
		var v_id : int = voxel.get_cell(v)
		for dir in neighbour_directions:
			# Get ne neighbour coordinate.
			var neighbour: Vector3i = v + dir
			var n_id : int = voxel.get_cell(neighbour)
			# Is the neighbour connected by an edge?
			var mask : int = Math.ID_MASK[normal + dir]
			if Math.shift_face(n_id, dir) & v_id & mask != mask:
				continue # No interface with adjacent cell.
			# Is the neighbour has a non null surface?
			if n_id & mask == 0:
				continue
			# Is the edge covered by an occluder?
			# Get the cell on top of the candidate if any.
			var occluder: Vector3i = neighbour + normal
			var o_id: int = voxel.get_cell(occluder)
			mask = Math.ID_MASK[-normal - dir]
			if o_id & mask == mask:
				continue # Edge covered by an occluder.
			neighbours.append(neighbour)


class FaceTool:
	extends Tool
	enum { LURK, PUSH_PULL }
	var state = LURK
	var face # List of cells
	func name() -> String:
		return "Face tool"

	func on_input(editor: VoxelEditor, camera: Camera3D, event: InputEvent):
		if not event is InputEventMouse:
			return
		match state:
			LURK:
				var pick = __try_pick_with_highlight(editor, camera, event, FACES)
				if Event.LeftButton(event) and pick.result:
					state = PUSH_PULL
					var g = FaceGraph.new(editor.voxel, pick.snapping)
					var coords : Array = Graphs.DFS(g, pick.coord)
					editor.gizmo_plugin.highlight(editor.voxel, coords, pick.result.normal, pick.snapping)
					# Compute the exposed mask for each cells.
					return CONSUME_EVENT
			PUSH_PULL:
				if Event.LeftRelease(event):
					return QUIT
		return CONSUME_EVENT

class VolumeCreationTool:
	extends Tool

	enum State { LURK, DEFINING_SURFACE, DEFINIG_VOLUME }

	var first_click_normal: Vector3i
	var click_coords = [null, null, null]
	var state: State = State.LURK
	var plane = Plane(Vector3.UP, -.49)

	func name() -> String:
		return "Volume tool"

	func __aabb() -> AABB:
		var aabb = AABB(click_coords[0].round(), Vector3.ZERO)
		for v in click_coords:
			if v != null:
				aabb = aabb.expand(v.round())
		return aabb

	func on_input(editor: VoxelEditor, camera: Camera3D, event: InputEvent) -> int:
		if event is InputEventKey:
			if event.keycode == KEY_ESCAPE:
				return QUIT
		elif event is InputEventMouse:
			var r = on_mouse_input(editor, camera, event)
			if r != null:
				return r
			return CONSUME_EVENT if event is InputEventMouseButton and event.button == 1 else PASS_EVENT
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

				plane = Plane(first_click_normal, click_coords[0])
				editor.gizmo_plugin.debug_point = click_coords[0]
				editor.gizmo_plugin.draw_volume(editor.voxel, __aabb())
				if Event.LeftPress(event):
					state = State.DEFINING_SURFACE
					return CONSUME_EVENT

			State.DEFINING_SURFACE:
				var picked_point = plane.intersects_ray(
					camera.project_ray_origin(event.position),
					camera.project_ray_normal(event.position)
				)
				if picked_point == null:
					return
				click_coords[1] = picked_point
				editor.gizmo_plugin.debug_point = picked_point
				editor.gizmo_plugin.draw_volume(editor.voxel, __aabb())
				if Event.LeftRelease(event):
					# When the press and release happened on the same cell.
					if click_coords[0].round() == click_coords[1].round():
						editor.do_paint_volume_action(
							editor.voxel, __aabb(), VoxelNode.CUBE, editor.palette.color
						)
						print("I want to quit!")
						return QUIT
					state = State.DEFINIG_VOLUME
					return CONSUME_EVENT

			State.DEFINIG_VOLUME:
				var approach = Math.line_intersection(
					click_coords[1],
					first_click_normal,
					camera.project_ray_origin(event.position),
					camera.project_ray_normal(event.position)
				)
				click_coords[2] = approach
				editor.gizmo_plugin.draw_volume(editor.voxel, __aabb())
				editor.gizmo_plugin.debug_point = approach
				if Event.LeftRelease(event):
					editor.do_paint_volume_action(
						editor.voxel, __aabb(), VoxelNode.CUBE, editor.palette.color
					)
					return QUIT
				elif Event.RightRelease(event):
					editor.do_paint_volume_action(editor.voxel, __aabb(), 0, editor.palette.color)
					return QUIT

var last_mouse_event

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if voxel == null:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouse:
		last_mouse_event = event
	if event is InputEventKey and event.pressed and event.echo == false:
		match event.keycode:
			KEY_V:
				current_tool = VolumeCreationTool.new()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			KEY_ESCAPE:
				print("Tool quit")
				current_tool = PaintTool.new()
				gizmo_plugin.clear()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			KEY_F:
				var pick = Tool.__inresect_pick_ray(camera, last_mouse_event)
				if pick.result != null:
					print("Attempt to focuss on ", pick)
					var last_voxel = voxel
					var es : EditorSelection = get_editor_interface().get_selection()
					es.clear()
					es.add_node(pick.result.collider)
					
					var get_back_to_it = func ():
						print("Getting back to it")
						es.clear()
						es.add_node(last_voxel)
						return EditorPlugin.AFTER_GUI_INPUT_STOP
					# Wait a few moments before switching back to editing the voxel.
					var t = camera.get_tree().create_timer(.05)
					t.timeout.connect(get_back_to_it)
					# Let the F key be interpreted by godot editor.
					return EditorPlugin.AFTER_GUI_INPUT_PASS
			KEY_C:
				current_tool = FaceTool.new()
				gizmo_plugin.clear()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
				
	var r = current_tool.on_input(self, camera, event)
	if r == Tool.QUIT:
		print("Tool quit")
		gizmo_plugin.clear()
		current_tool = PaintTool.new()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	elif r == VolumeCreationTool.CONSUME_EVENT:
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS



class PaintTool:
	extends Tool
	var last_map_position = null

	func name() -> String:
		return "Paint tool"
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
			var snapping = __snap_one_sub_element(
				global_to_map_coord * pick.result.position - cell_node.position,
				local_normal,
				7
			)

			last_map_position = map_position
			editor.gizmo_plugin.highlight(voxel_node, [map_position], pick.result.normal, snapping)

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
						new_mesh_id &= Math.ID_MASK[-n]
						print("masked cell %x" % new_mesh_id)
						new_mesh_id |= Math.shift_face(new_mesh_id, n)
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
								Math.ID_MASK[-new_cell_rel_pos] | Math.ID_MASK[snapping - new_cell_rel_pos]
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
								Math.ID_MASK[-t] | Math.ID_MASK[-u],
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
								Math.ID_MASK[-t] | Math.ID_MASK[-u] | Math.ID_MASK[-v],
								voxel_node.get_cell_color(map_position)
							)
			else:
				return PASS_EVENT

		return PASS_EVENT
