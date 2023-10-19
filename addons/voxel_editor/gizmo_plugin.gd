extends EditorNode3DGizmoPlugin

const VoxelNode = preload("voxel_node.gd")
const SelectMaterial = preload("select.tres")

var box = BoxMesh.new()
var current_highlight = null


func _get_gizmo_name():
	return "Voxel Editor"


func _init():
	add_material("main", preload("material.tres"))


func _has_gizmo(node):
	return node is VoxelNode


func clear_highlight():
	var previous_node = current_highlight.voxel_node if current_highlight else null
	current_highlight = null
	if previous_node:
		previous_node.update_gizmos()


func highlight(voxel_node: VoxelNode, coord: Vector3i, normal: Vector3, snapping: Vector3i):
	var previous_highlight = current_highlight
	current_highlight = {
		voxel_node = voxel_node, coord = coord, normal = normal, snapping = snapping
	}
	if previous_highlight and previous_highlight.voxel_node != voxel_node:
		previous_highlight.voxel_node.update_gizmos()
	if previous_highlight != current_highlight:
		voxel_node.update_gizmos()


func _redraw(gizmo: EditorNode3DGizmo):
	gizmo.clear()
	if current_highlight == null:
		print("Clear gizmo")
		return
	if gizmo.get_node_3d() != current_highlight.voxel_node:
		return
	if current_highlight.snapping.length_squared() > 1:
		box.size = Vector3(1., 1., 1.) - 0.96 * Vector3(current_highlight.snapping).abs()
		var tr = Transform3D()
		tr.origin = Vector3(current_highlight.coord) + Vector3(current_highlight.snapping) * .5
		gizmo.add_mesh(box, get_material("main", gizmo), tr)
	else:
		var voxel = gizmo.get_node_3d()
		var mesh_id = voxel.get_cell(current_highlight.coord)

		if not mesh_id:
			return  # TO BE REMOVED. It is there to ensure assert does not messup with godot
		assert(mesh_id != 0)
		var instanciation_data = voxel.mesh_index_map[mesh_id]
		var transform = Transform3D()
		transform.origin = Vector3(current_highlight.coord)
		transform.basis = instanciation_data.basis
		SelectMaterial.set_shader_parameter("pick_normal", current_highlight.normal)
		gizmo.add_mesh(instanciation_data.mesh, SelectMaterial, transform)
