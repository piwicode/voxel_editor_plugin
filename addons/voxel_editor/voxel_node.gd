@tool
extends Node3D

const CUBE = 255
# Describe the voxel completely.
# Stores { mesh_id = int, color = Color } indexed by Vector3i coordinates.
@export var map: Dictionary = {}

# Stores { scene = PackedScene, mesh = Mesh, basis = Basis } indexed by mesh id.
# The mesh id is a 8 bit integer, one per cube corner, set to 1 when there is
# matter. bits are in order packed x first then y, then z.
var mesh_index_map: Dictionary = build_mesh_index_map()

# Stores StandardMaterial3D indexed by Color.
var material_map: Dictionary

const BOX_AXIS_VALUES = [-0.5, 0.5]
const MESH_ID_SEEDS = [0x17, 0x5f, 0x7f, 0xff]
const ORTHO_BASES = [
	Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)),
	Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)),
	Basis(Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1)),
	Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)),
	Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)),
	Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)),
	Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)),
	Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)),
	Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)),
	Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)),
	Basis(Vector3(0, -1, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)),
	Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)),
	Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)),
	Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)),
	Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)),
	Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
	Basis(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)),
	Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1, 0, 0)),
	Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)),
	Basis(Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(1, 0, 0)),
	Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
	Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)),
	Basis(Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0))
]

const FaceShift = {
	Vector3i(1, 0, 0): 1,
	Vector3i(0, 1, 0): 2,
	Vector3i(0, 0, 1): 4,
	Vector3i(-1, 0, 0): -1,
	Vector3i(0, -1, 0): -2,
	Vector3i(0, 0, -1): -4
}


func get_material_for(color: Color) -> StandardMaterial3D:
	if not color in material_map:
		var new_material = StandardMaterial3D.new()
		new_material.albedo_color = color
		material_map[color] = new_material
	return material_map[color]


static func transform_id(mesh_id: int, basis: Basis) -> int:
	var result = 0
	var p2 = Vector3(1, 2, 4)  # Powers of two.
	for z in BOX_AXIS_VALUES:
		for y in BOX_AXIS_VALUES:
			for x in BOX_AXIS_VALUES:
				var v = basis * Vector3(x, y, z) + Vector3(.5, .5, .5)
				var write_bit = int(v.dot(p2))
				result |= (mesh_id & 1) << write_bit
				mesh_id >>= 1
	return result


static func build_mesh_index_map() -> Dictionary:
	var start_time = Time.get_ticks_msec()
	var mapping = {}

	for mesh_id in MESH_ID_SEEDS:
		var scene = load("res://addons/voxel_editor/res/mesh_%d.tscn" % mesh_id)
		var mesh = load("res://addons/voxel_editor/res/mesh_%d.res" % mesh_id)
		for basis in ORTHO_BASES:
			var rotated_mesh_id = transform_id(mesh_id, basis)
			if not rotated_mesh_id in mapping:
				mapping[rotated_mesh_id] = {scene = scene, mesh = mesh, basis = basis}

	print("Done in %d ms" % (Time.get_ticks_msec() - start_time))
	return mapping


static func coord_to_name(coord: Vector3i) -> String:
	return "%s" % coord


func set_cell(coord: Vector3i, mesh_id: int, color: Color):
	print("set cell ", coord, " to ", mesh_id, " with color ", color)
	assert(mesh_id == 0 or mesh_id in mesh_index_map, "Unknown mesh_id")
	if coord in map:
		var child = get_node(NodePath(coord_to_name(coord)))
		print("remove child ", child)
		remove_child(child)
		child.queue_free()
	if mesh_id == 0:
		map.erase(coord)
	else:
		map[coord] = {mesh_id = mesh_id, color = color}
		__instantiate_cell(coord, mesh_id, color)


func get_cell(coord: Vector3i) -> int:
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
	for z in BOX_AXIS_VALUES:
		for y in BOX_AXIS_VALUES:
			for x in BOX_AXIS_VALUES:
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
	face.neighbour_mask = id << max(0, FaceShift[-n_i]) >> max(0, -FaceShift[-n_i]) if outer else 0
	face.neighbour_value = id << max(0, FaceShift[-n_i]) >> max(0, -FaceShift[-n_i]) if outer else 0
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
		for basis in ORTHO_BASES:
			var id = transform_id(seed.id, basis)
			if id in face_by_id:
				continue
			var face: Face = Face.new()

			face.mask = transform_id(seed.mask, basis)
			face.id = id
			# TODO: use the basis once Basis implement * operator for PackedVector3Array
			face.vertices = Transform3D(basis, Vector3.ZERO) * seed.vertices
			face.normal = basis * seed.normal
			face.neighbour = Vector3i(basis * seed.normal) if seed.neighbour else Vector3i.ZERO
			face.neighbour_mask = transform_id(seed.neighbour_mask, basis) if seed.neighbour else 0
			face.neighbour_value = (
				transform_id(seed.neighbour_value, basis) if seed.neighbour else 0
			)
			face_by_id[id] = face

	var faces_by_mesh_id: Dictionary = {}
	for mesh_id_seeds in MESH_ID_SEEDS:
		for basis in ORTHO_BASES:
			var mesh_id: int = transform_id(mesh_id_seeds, basis)
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
	print("Export mesh")
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
				if get_cell(coord + face.neighbour) & face.neighbour_mask == face.neighbour_value:
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

	# Try to get the resource from the resource cache, if found modify it in
	# place so that the editors gets updated.
	var arr_mesh = load("res://export_test.tres")
	if arr_mesh == null:  # Otherwise create a new resource.
		arr_mesh = ArrayMesh.new()
	arr_mesh.clear_surfaces()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var time_mesh_done = Time.get_ticks_usec()
	ResourceSaver.save(arr_mesh, "res://export_test.tres", ResourceSaver.FLAG_COMPRESS)
	print("Done ", vertices.size(), " vertices (", skipped, " skipped)")
	print(" - geom ", (time_geom_done - time_start) / 1000., " ms")
	print(" - mesh ", (time_mesh_done - time_geom_done) / 1000., " ms")
	print(" - all ", (time_mesh_done - time_start) / 1000., " ms")


func _enter_tree():
	if map.size() == 0:
		map[Vector3i(0, 0, 0)] = {mesh_id = 255, color = Color(1, 0, 0)}
		map[Vector3i(2, 0, 0)] = {mesh_id = 95, color = Color.LIGHT_BLUE}
		map[Vector3i(4, 0, 0)] = {mesh_id = 127, color = Color.WEB_GRAY}
		map[Vector3i(6, 0, 0)] = {mesh_id = 23, color = Color.WEB_GRAY}
		map[Vector3i(2, 2, 0)] = {mesh_id = 63, color = Color.WEB_GRAY}

	# Clicking a children will edit this node.
	set_meta("_edit_group_", true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
