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
const MESH_BF_SEEDS = [0x17, 0x5f, 0x7f, 0xff]
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


func get_material_for(color: Color) -> StandardMaterial3D:
	if not color in material_map:
		var new_material = StandardMaterial3D.new()
		new_material.albedo_color = color
		material_map[color] = new_material
	return material_map[color]


static func transform_bf(mesh_id: int, basis: Basis) -> int:
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

	for mesh_id in MESH_BF_SEEDS:
		var scene = load("res://addons/voxel_editor/mesh_%d.tscn" % mesh_id)
		var mesh = load("res://addons/voxel_editor/mesh_%d.res" % mesh_id)
		for basis in ORTHO_BASES:
			var rotated_mesh_id = transform_bf(mesh_id, basis)
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


static func make_face(mask: int, bf: int, vertices: int, normal: Vector3):
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
	return {mask = mask, bf = bf, vertices = vertex_array, normal = normal.normalized()}


func export_mesh():
	print("Export mesh")
	var face_seeds = [
		make_face(0x0f, 0x0f, 0x0f, Vector3(0, 0, -1)),  # outer square.
		make_face(0x0f, 0x07, 0x07, Vector3(0, 0, -1)),  # outer triangle.
		make_face(0xff, 0x5f, 0x5a, Vector3(1, 0, 1)),  # inner square.
		make_face(0xff, 0x17, 0x16, Vector3(1, 1, 1)),  # inner triangle.
		make_face(0xff, 0x7f, 0x68, Vector3(1, 1, 1)),  # inner triangle.
	]

	var face_by_bf = {}
	for face in face_seeds:
		for basis in ORTHO_BASES:
			var bf = transform_bf(face.bf, basis)
			if bf in face_by_bf:
				continue
			face_by_bf[bf] = {
				mask = transform_bf(face.mask, basis),
				bf = bf,
				# TODO: use the basis once Basis implement * operator for PackedVector3Array.
				vertices = Transform3D(basis, Vector3.ZERO) * face.vertices,
				normal = basis * face.normal
			}

	print(face_seeds)
	var faces_by_mesh_bf = {}
	for mesh_bf_seeds in MESH_BF_SEEDS:
		for basis in ORTHO_BASES:
			var mesh_bf = transform_bf(mesh_bf_seeds, basis)
			if mesh_bf in faces_by_mesh_bf:
				continue
			var faces = []
			for face in face_by_bf.values():
				if mesh_bf & face.mask == face.bf:
					faces.append(face)
			faces_by_mesh_bf[mesh_bf] = faces

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var UV_LST = {
		3: PackedVector2Array([Vector2(1, 0), Vector2(1, -1), Vector2(0, 0)]),
		6:
		PackedVector2Array(
			[
				Vector2(0, 0),
				Vector2(1, 0),
				Vector2(1, 1),
				Vector2(1, 1),
				Vector2(0, 1),
				Vector2(0, 0)
			]
		)
	}
	for coord in map:
		var cell = map[coord]
		for face in faces_by_mesh_bf[cell.mesh_id]:
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

	# Try to get the resource from the resource cache, if found modify it in
	# place so that the editors gets updated.
	var arr_mesh = load("res://export_test.tres")
	if arr_mesh == null:  # Otherwise create a new resource.
		arr_mesh = ArrayMesh.new()
	arr_mesh.clear_surfaces()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	ResourceSaver.save(arr_mesh, "res://export_test.tres", ResourceSaver.FLAG_COMPRESS)
	print("Done")


func backup():
	var mesh_id = 127
	var vertices = PackedVector3Array()

	for z in BOX_AXIS_VALUES:
		for y in BOX_AXIS_VALUES:
			for x in BOX_AXIS_VALUES:
				if mesh_id & 1:
					vertices.append(Vector3(x, y, z))
				mesh_id >>= 1
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var convex_shape = arr_mesh.create_convex_shape()
	var mesh = convex_shape.get_debug_mesh()
	ResourceSaver.save(mesh, "res://export_test.tres", ResourceSaver.FLAG_COMPRESS)
	print(
		ResourceLoader.new().load(
			"res://export_test.tres", "ArrayMesh", ResourceLoader.CACHE_MODE_REPLACE
		)
	)


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
