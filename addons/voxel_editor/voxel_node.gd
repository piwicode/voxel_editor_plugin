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


func get_material_for(color: Color) -> StandardMaterial3D:
	if not color in material_map:
		var new_material = StandardMaterial3D.new()
		new_material.albedo_color = color
		material_map[color] = new_material
	return material_map[color]


static func transform(mesh_id: int, basis: Basis) -> int:
	var result = 0
	var p2 = Vector3(1, 2, 4)  # Powers of two.
	for z in [.5, -.5]:
		for y in [.5, -.5]:
			for x in [.5, -.5]:
				var v = basis * Vector3(x, y, z) + Vector3(.5, .5, .5)
				var write_bit = int(v.dot(p2))
				result |= (mesh_id & 1) << write_bit
				mesh_id >>= 1
	return result


static func build_mesh_index_map() -> Dictionary:
	var start_time = Time.get_ticks_msec()
	var mapping = {}
	var gridmap = GridMap.new()
	for mesh_id in [23, 95, 127, 255]:
		var scene = load("res://addons/voxel_editor/mesh_%d.tscn" % mesh_id)
		var mesh = load("res://addons/voxel_editor/mesh_%d.res" % mesh_id)
		for ort_idx in range(24):
			var basis = gridmap.get_basis_with_orthogonal_index(ort_idx)
			var rotated_mesh_id = transform(mesh_id, basis)
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
		_instantiate(coord, mesh_id, color)


func get_cell(coord: Vector3i) -> int:
	if coord in map:
		return map[coord].mesh_id
	return 0


func get_cell_color(coord: Vector3i) -> Color:
	if coord in map:
		return map[coord].color
	return Color.WHITE_SMOKE


func _instantiate(coord: Vector3i, mesh_id: int, color: Color):
	var data = mesh_index_map[mesh_id]
	var child = data.scene.instantiate()
	child.name = coord_to_name(coord)
	child.position = Vector3(coord)
	child.basis = data.basis
	child.material_override = get_material_for(color)
	add_child(child)


func _ready():
	print("Ready")
	for key in map.keys():
		var cell = map[key]
		_instantiate(key, cell.mesh_id, cell.color)


func _enter_tree():
	print("Add box to Voxel")
	if map.size() == 0:
		map[Vector3i(0, 0, 0)] = {mesh_id = 255, color = Color.LIGHT_GREEN}
		map[Vector3i(2, 0, 0)] = {mesh_id = 95, color = Color.LIGHT_BLUE}
		map[Vector3i(4, 0, 0)] = {mesh_id = 127, color = Color.WEB_GRAY}
		map[Vector3i(6, 0, 0)] = {mesh_id = 23, color = Color.WEB_GRAY}
		map[Vector3i(2, 2, 0)] = {mesh_id = 63, color = Color.WEB_GRAY}

	# Clicking a children will edit this node.
	set_meta("_edit_group_", true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
