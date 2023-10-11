extends EditorNode3DGizmoPlugin

const VoxelNode = preload("voxel_node.gd")
const SelectMaterial = preload("select.tres")
var box = BoxMesh.new()

func _get_gizmo_name():
	return "Face"

func _init():
	add_material("main", preload("material.tres"))
	create_handle_material("handles")

func _has_gizmo(node):
	return node is VoxelNode
	
var current_coord = null
var current_normal = null
var current_snapping = null

func highlight(coord, normal, snapping):
	var changed = (
		current_coord != coord or 
		current_normal != normal or 
		snapping != current_snapping)
	if changed:
#		print({coord=coord, normal=normal, snapping=snapping})
		current_coord = coord
		current_normal = normal
		current_snapping = snapping
	return changed


func _redraw(gizmo):
	gizmo.clear()
#	print(current_coord)
	if not current_coord:
		print("Clear gizmo")
		return
	

	if current_snapping.length_squared() > 1:
		box.size = Vector3(1., 1., 1.) - 0.96 * Vector3(current_snapping).abs() 
		var tr = Transform3D();
		tr.origin = Vector3(current_coord) + Vector3(current_snapping) * .5
		gizmo.add_mesh(box, get_material("main", gizmo), tr)
	else:
		var voxel = gizmo.get_node_3d()
		var mesh_id = voxel.get_cell(current_coord)
		var instanciation_data = voxel.mesh_index_map[mesh_id]
		var transform = Transform3D()
		transform.origin = Vector3(current_coord)
		transform.basis = instanciation_data.basis
		SelectMaterial.set_shader_parameter("pick_normal", current_normal)
		gizmo.add_mesh(instanciation_data.mesh, SelectMaterial, transform)

