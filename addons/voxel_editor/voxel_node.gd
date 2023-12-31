@tool
extends Node3D
class_name VoxelNode

# Mesh_id of a CUBE.
const CUBE = 255

# Describe the voxel completely.
# Stores { mesh_id = int, color = Color } indexed by Vector3i coordinates.
@export var map: Dictionary = {}

# Location of the exported mesh.
# If empty, the mesh name is derived from the Node name.
@export var export_path: String = ""

# Stores { scene = PackedScene, mesh = Mesh, basis = Basis } indexed by mesh id.
# The mesh id is a 8 bit integer, one per cube corner, set to 1 when there is
# matter. bits are in order packed x first then y, then z.
var mesh_index_map: Dictionary = build_mesh_index_map()

# Caches StandardMaterial3D indexed by Color.
var material_map: Dictionary

const MESH_ID_SEEDS = [0x17, 0x5f, 0x7f, 0xff]


func get_material_for(color: Color) -> StandardMaterial3D:
	if not color in material_map:
		var new_material = StandardMaterial3D.new()
		new_material.albedo_color = color
		material_map[color] = new_material
	return material_map[color]


static func build_mesh_index_map() -> Dictionary:
	var start_time = Time.get_ticks_msec()
	var mapping = {}

	for mesh_id in MESH_ID_SEEDS:
		var scene = load("res://addons/voxel_editor/res/mesh_%d.tscn" % mesh_id)
		var mesh = load("res://addons/voxel_editor/res/mesh_%d.res" % mesh_id)
		for basis in Math.ORTHO_BASES:
			var rotated_mesh_id = Math.transform_id(mesh_id, basis)
			if not rotated_mesh_id in mapping:
				mapping[rotated_mesh_id] = {scene = scene, mesh = mesh, basis = basis}

	print("Done in %d ms" % (Time.get_ticks_msec() - start_time))
	return mapping


static func coord_to_name(coord: Vector3i) -> String:
	return "%s" % coord


func set_cell(coord: Vector3i, mesh_id: int, color: Color):
#	print("set cell ", coord, " to ", mesh_id, " with color ", color)
	assert(mesh_id == 0 or mesh_id in mesh_index_map, "Unknown mesh_id")
	if coord in map:
		var cell = map[coord]
		if cell.mesh_id == mesh_id and cell.color == color:
			return
		var child = get_node(NodePath(coord_to_name(coord)))
		remove_child(child)
		child.queue_free()
	elif mesh_id == 0:
		return
	print("Update voxel tree")
	if mesh_id == 0:
		map.erase(coord)
	else:
		map[coord] = {mesh_id = mesh_id, color = color}
		__instantiate_cell(coord, mesh_id, color)


func get_cell(coord: Vector3i):
	if coord in map:
		return map[coord].duplicate()


func get_cell_id(coord: Vector3i) -> int:
	if coord in map:
		return map[coord].mesh_id
	return 0


func get_cell_color(coord: Vector3i) -> Color:
	if coord in map:
		return map[coord].color
	return Color.WHITE_SMOKE


func __instantiate_cell(coord: Vector3i, mesh_id: int, color: Color):
	var name = coord_to_name(coord)
	var data = mesh_index_map[mesh_id]
	var child = data.scene.instantiate()
	child.name = coord_to_name(coord)
	child.position = Vector3(coord)
	child.basis = data.basis
	child.material_override = get_material_for(color)
	add_child(child)


func _ready():
	print("Ready")
	connect("visibility_changed", _on_visibility_changed)
	# Clear children so that we don't get duplicated cells when the node is copied.
	__clear_cell_children()
	__populate_cell_children()


func __clear_cell_children():
	for child in get_children():
		if not child.owner:
			remove_child(child)
			child.queue_free()


func __populate_cell_children():
	for key in map.keys():
		__instantiate_cell(key, map[key].mesh_id, map[key].color)


func _on_visibility_changed():
	if is_visible_in_tree():
		__populate_cell_children()
	else:
		__clear_cell_children()


class Face:
	var mask: int
	var id: int
	var vertices: PackedVector3Array
	var normal: Vector3
	var neighbour: Vector3i
	var neighbour_mask: int
	var neighbour_value: int


static func __make_face(mask: int, id: int, vertices: int, normal: Vector3, outer: bool) -> Face:
	var vertex_array = PackedVector3Array()
	var bits = vertices
	for z in Math.BOX_AXIS_VALUES:
		for y in Math.BOX_AXIS_VALUES:
			for x in Math.BOX_AXIS_VALUES:
				if bits & 1:
					vertex_array.append(Vector3(x, y, z))
				bits >>= 1

	if vertex_array.size() == 4:
		vertex_array.insert(2, vertex_array[3])
		vertex_array.insert(3, vertex_array[4])
		vertex_array[5] = vertex_array[0]

	assert(vertex_array.size() % 3 == 0)
	if (vertex_array[0] - vertex_array[1]).cross(vertex_array[1] - vertex_array[2]).dot(normal) > 0:
		vertex_array.reverse()
	var n_i = Vector3i(normal)
	var face: Face = Face.new()

	face.mask = mask
	face.id = id
	face.vertices = vertex_array
	face.normal = normal.normalized()
	face.neighbour = n_i if outer else Vector3i.ZERO
	face.neighbour_mask = Math.shift_face(id, -n_i) if outer else 0
	face.neighbour_value = Math.shift_face(id, -n_i) if outer else 0
	return face


static func __build_faces_by_mesh_id() -> Dictionary:
	print("Generate mesh export primitives.")
	var face_seeds = [
		__make_face(0x0f, 0x0f, 0x0f, Vector3(0, 0, -1), true),  # outer square.
		__make_face(0x0f, 0x07, 0x07, Vector3(0, 0, -1), true),  # outer triangle.
		__make_face(0xff, 0x5f, 0x5a, Vector3(1, 0, 1), false),  # inner square.
		__make_face(0xff, 0x17, 0x16, Vector3(1, 1, 1), false),  # inner triangle.
		__make_face(0xff, 0x7f, 0x68, Vector3(1, 1, 1), false),  # inner triangle.
	]

	var face_by_id = {}
	for seed in face_seeds:
		for basis in Math.ORTHO_BASES:
			var id = Math.transform_id(seed.id, basis)
			if id in face_by_id:
				continue
			var face: Face = Face.new()

			face.mask = Math.transform_id(seed.mask, basis)
			face.id = id
			# TODO: use the basis once Basis implement * operator for PackedVector3Array
			face.vertices = Transform3D(basis, Vector3.ZERO) * seed.vertices
			face.normal = basis * seed.normal
			face.neighbour = Vector3i(basis * seed.normal) if seed.neighbour else Vector3i.ZERO
			face.neighbour_mask = (
				Math.transform_id(seed.neighbour_mask, basis) if seed.neighbour else 0
			)
			face.neighbour_value = (
				Math.transform_id(seed.neighbour_value, basis) if seed.neighbour else 0
			)
			face_by_id[id] = face

	var faces_by_mesh_id: Dictionary = {}
	for mesh_id_seeds in MESH_ID_SEEDS:
		for basis in Math.ORTHO_BASES:
			var mesh_id: int = Math.transform_id(mesh_id_seeds, basis)
			if mesh_id in faces_by_mesh_id:
				continue
			var faces: Array[Face] = []
			for face in face_by_id.values():
				if mesh_id & face.mask == face.id:
					faces.append(face)
			faces_by_mesh_id[mesh_id] = faces

	return faces_by_mesh_id


static var FACES_BY_MESH_ID = __build_faces_by_mesh_id()

static var UV_LST: Dictionary = {
	3: PackedVector2Array([Vector2(1, 0), Vector2(1, -1), Vector2(0, 0)]),
	6:
	PackedVector2Array(
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0)]
	)
}


func export_mesh():
	var faces_by_mesh_id: Dictionary = FACES_BY_MESH_ID
	var time_start = Time.get_ticks_usec()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var skipped = 0
	for coord in map:
		var cell = map[coord]
		for face_v in faces_by_mesh_id[cell.mesh_id]:
			var face: Face = face_v
			if face.neighbour:
				if (
					get_cell_id(coord + face.neighbour) & face.neighbour_mask
					== face.neighbour_value
				):
					skipped += face.vertices.size()
					continue  # If the neighbour covers that face.

			# Skip if the face is replicated on the contiguous cube.
			uvs.append_array(UV_LST[face.vertices.size()])
			for vertex in face.vertices:
				vertices.append(vertex + Vector3(coord))
				normals.append(face.normal)
				colors.append(cell.color.srgb_to_linear())

	var arrays = []
	arrays.resize(max(Mesh.ARRAY_MAX, Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV))
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var time_geom_done = Time.get_ticks_usec()

	if not export_path:
		export_path = (
			get_tree().get_edited_scene_root().scene_file_path.trim_suffix(".tscn")
			+ "_"
			+ get_name()
			+ ".res"
		)
	print("Export mesh ", export_path)
	# Try to get the resource from the resource cache, if found modify it in
	# place so that the editors gets updated.
	var arr_mesh = load(export_path)
	if arr_mesh == null:  # Otherwise create a new resource.
		arr_mesh = ArrayMesh.new()
	arr_mesh.clear_surfaces()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.surface_set_material(0, load("res://addons/voxel_editor/material/edge_shader.tres"))
	var time_mesh_done = Time.get_ticks_usec()
	ResourceSaver.save(arr_mesh, export_path, ResourceSaver.FLAG_COMPRESS)
	print("Done ", vertices.size(), " vertices (", skipped, " skipped)")
	print(" - geom ", (time_geom_done - time_start) / 1000., " ms")
	print(" - mesh ", (time_mesh_done - time_geom_done) / 1000., " ms")
	print(" - all ", (time_mesh_done - time_start) / 1000., " ms")

	var mc = mass_characteristics()
	print(mc)
	var mesh_instance : MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = arr_mesh

	var rigid_body : RigidBody3D = RigidBody3D.new()
	rigid_body.name = "RigidBody3D"
	rigid_body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	rigid_body.center_of_mass = mc.g
	rigid_body.inertia = mc.j
	rigid_body.mass = mc.mass
	rigid_body.add_child(mesh_instance)
	mesh_instance.owner = rigid_body

	var scene = PackedScene.new()
	scene.pack(rigid_body)
	
	var scene_resource_path = export_path.trim_prefix(".res") + ".tscn"
	ResourceSaver.save(scene, scene_resource_path)
	
	mesh_instance.queue_free()
	rigid_body.queue_free()
	
func mass_characteristics():
	var mass : float = float(map.size())
	# Compute center of mass.
	var sum : Vector3i = Vector3i()
	for c in map:
		sum += c
	var g : Vector3 = Vector3(sum) / mass
	# Compute inertia matrix diagonal.
	var j : Vector3 = Vector3()
	for c in map:
		var r2 : Vector3 = Vector3(c) - g
		r2 *= r2
		j.x += r2.y + r2.z
		j.y += r2.x + r2.z
		j.z += r2.x + r2.y
	return {mass=mass, g=g, j=j}

func _enter_tree():
	if map.size() == 0:
		map[Vector3i(0, 0, 0)] = {mesh_id = 255, color = Color(1, 0, 0)}
		map[Vector3i(2, 0, 0)] = {mesh_id = 95, color = Color.LIGHT_BLUE}
		map[Vector3i(4, 0, 0)] = {mesh_id = 127, color = Color.WEB_GRAY}
		map[Vector3i(6, 0, 0)] = {mesh_id = 23, color = Color.WEB_GRAY}
		map[Vector3i(2, 2, 0)] = {mesh_id = 63, color = Color.WEB_GRAY}

	# Clicking a children will edit this node.
	set_meta("_edit_group_", true)


# Accumulates changes applied to a voxel with undo capabilities.
class Snapshot:
	const EMPTY_CELL = {mesh_id = 0, color = Color(0, 0, 0)}

	var voxel: VoxelNode
	var backup: Dictionary = {}
	var edits: Dictionary = {}

	func _init(voxel: VoxelNode):
		self.voxel = voxel

	func clear_cell(coord: Vector3i):
		set_cell(coord, EMPTY_CELL.mesh_id, EMPTY_CELL.color)

	func set_cell(coord: Vector3i, mesh_id: int, color: Color):
		if not coord in backup:
			backup[coord] = voxel.map.get(coord, EMPTY_CELL)
		edits[coord] = {mesh_id = mesh_id, color = color}

	# Clears all edits. Call apply to update the voxel.
	func rollback():
		edits.clear()

	func apply():
		var stat_change: int = 0
		for coord in edits:
			var cell: Dictionary = edits[coord]
			voxel.set_cell(coord, cell.mesh_id, cell.color)
			stat_change += 1
		for coord in backup.keys():
			if not coord in edits:
				var cell: Dictionary = backup[coord]
				voxel.set_cell(coord, cell.mesh_id, cell.color)
				backup.erase(coord)
				stat_change += 1
		print("Applied %d edit %d backup %d changes" % [edits.size(), backup.size(), stat_change])
