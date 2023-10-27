class_name GizmoPlugin
extends EditorNode3DGizmoPlugin

const SelectMaterial = preload("select.tres")
var debug_point
var __current_drawable = null
var __current_voxel = null


func _get_gizmo_name():
	return "Voxel Editor"


func _init():
	add_material("main", preload("material.tres"))


func _has_gizmo(node):
	return node is VoxelNode


func clear():
	var previous_voxel = __current_voxel
	__current_voxel = null
	__current_drawable = null
	if previous_voxel:
		previous_voxel.update_gizmos()


func __draw(voxel_node: VoxelNode, drawable: Drawable):
	var previous_voxel = __current_voxel
	__current_voxel = voxel_node

	if previous_voxel and previous_voxel != voxel_node:
		previous_voxel.update_gizmos()

	if __current_drawable != drawable:
		__current_drawable = drawable
		voxel_node.update_gizmos()


func _redraw(gizmo: EditorNode3DGizmo):
	gizmo.clear()
	if __current_drawable == null:
		return
	if gizmo.get_node_3d() != __current_voxel:
		return
	__current_drawable.draw(self, gizmo)
	if debug_point:
		var vertices = PackedVector3Array()
		for d in [Vector3.UP, Vector3.BACK, Vector3.LEFT]:
			vertices.append(debug_point + d)
			vertices.append(debug_point - d)
		gizmo.add_lines(vertices, highlight_edge_material)


class Drawable:
	# The drawable should
	func draw(plugin: GizmoPlugin, gizmo: EditorNode3DGizmo):
		pass


var highlight_box: BoxMesh = BoxMesh.new()
const highlight_edge_material = preload("material.tres")
const highlight_face_material = preload("select.tres")


class Highlight:
	extends Drawable
	var coord: Vector3i
	var normal: Vector3
	var snapping: Vector3i

	func draw(plugin: GizmoPlugin, gizmo: EditorNode3DGizmo):
		if snapping.length_squared() > 1:
			# Highlight an edge or a point.
			plugin.highlight_box.size = Vector3(1., 1., 1.) - 0.96 * Vector3(snapping).abs()
			var tr = Transform3D()
			tr.origin = Vector3(coord) + Vector3(snapping) * .5
			gizmo.add_mesh(plugin.highlight_box, plugin.highlight_edge_material, tr)
		else:
			# Highlight a face.
			var voxel = gizmo.get_node_3d()
			var mesh_id = voxel.get_cell(coord)

			if not mesh_id:
				return  # TO BE REMOVED. It is there to ensure assert does not messup with godot
			assert(mesh_id != 0)
			var instanciation_data = voxel.mesh_index_map[mesh_id]
			var transform = Transform3D()
			transform.origin = Vector3(coord)
			transform.basis = instanciation_data.basis
			SelectMaterial.set_shader_parameter("pick_normal", normal)
			gizmo.add_mesh(instanciation_data.mesh, SelectMaterial, transform)


func highlight(voxel: VoxelNode, coord: Vector3i, normal: Vector3, snapping: Vector3i):
	var highlight = Highlight.new()
	highlight.coord = coord
	highlight.normal = normal
	highlight.snapping = snapping
	__draw(voxel, highlight)


class Volume:
	extends Drawable
	var aabb: AABB

	func draw(plugin: GizmoPlugin, gizmo: EditorNode3DGizmo):
		var vertices = PackedVector3Array()
		for x in range(2):
			for y in range(2):
				for z in range(2):
					var v1 = Vector3(x, y, z)
					for d in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
						var v2 = v1 + d * (Vector3.ONE - 2 * v1)
						if v1 < v2:
							vertices.append(aabb.position + v1 * aabb.size)
							vertices.append(aabb.position + v2 * aabb.size)
		gizmo.add_lines(vertices, plugin.highlight_edge_material)


func draw_volume(voxel: VoxelNode, aabb: AABB):
	var volume = Volume.new()
	volume.aabb = aabb
	volume.aabb.position -= Vector3(.5, .5, .5)
	volume.aabb.size += Vector3.ONE
	__draw(voxel, volume)
