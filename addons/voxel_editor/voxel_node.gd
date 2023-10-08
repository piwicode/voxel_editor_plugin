@tool
extends Node3D

@export var map: Dictionary = {}
var mesh_index_map: Dictionary = build_mesh_index_map()

static func transform(mesh_idx: int, basis: Basis):
	var result = 0
	var one = Vector3(1, 1, 1)
	var p2 = Vector3(1, 2, 4)

	for z in [1, 0]:
		for y in [1, 0]:
			for x in [1, 0]:
				var v = (basis * (Vector3(x, y, z) * 2.0 - one) + one) * 0.5 
				var read_bit = int(v.dot(p2))
				result <<= 1
				result += (mesh_idx >> read_bit) & 1
	return result

static func build_mesh_index_map():
	var start_time = Time.get_ticks_msec()
	var mapping = {}
	var gridmap = GridMap.new()
	for mesh_idx in [23, 95, 127, 255]:
		var scene = load("res://addons/voxel_editor/mesh_%d.tscn" % mesh_idx)
		for ort_idx in range(24):
			var basis = gridmap.get_basis_with_orthogonal_index(ort_idx)
			var rotated_mesh_idx = transform(mesh_idx, basis)
			if not rotated_mesh_idx in mapping:
#				print("INS ", {mesh_idx=mesh_idx, ort_idx=ort_idx, rotated_mesh_idx=rotated_mesh_idx, basis=basis})
				mapping[rotated_mesh_idx] = {scene=scene, basis=basis}
			else:
#				print("SKP", {mesh_idx=mesh_idx, ort_idx=ort_idx, rotated_mesh_idx=rotated_mesh_idx})
				pass
	print("Done in %d ms" % (Time.get_ticks_msec() - start_time))
	return mapping

static func coord_to_name(coord: Vector3i):
	return "%s" % coord

func set_cell(coord: Vector3i, mesh_idx: int):
	print("set cell ", coord, " ", mesh_idx)
	if coord in map:
		var child = get_node(NodePath(coord_to_name(coord)))
		print("remove child ", child)
		remove_child(child)
		child.queue_free()
	if mesh_idx == 0:
		map.erase(coord)
	else:
		map[coord] = mesh_idx
		_instantiate(coord, mesh_idx)
	
func _instantiate(coord: Vector3i, mesh_idx: int):
	var data = mesh_index_map[mesh_idx]
	var child = data.scene.instantiate()
	child.name = coord_to_name(coord)
	child.position = Vector3(coord)
	child.basis = data.basis
#	child.set_meta("_edit_lock_", true)
	add_child(child)
	print("instantiate ", {child=child, coord=coord, basis=data.basis, mesh_idx=mesh_idx})
	# No need to set owner as we don't want this child to be persisted
	# box.set_owner(get_tree().get_edited_scene_root())

func _ready():
	print("Ready")
	for key in map.keys():
		_instantiate(key, map[key])

func _enter_tree():
	print("Add box to Voxel")
	if map.size() == 0:
		map[Vector3i(0,0,0)] = 255
	# Clicking a children will edit this node.
	set_meta("_edit_group_", true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
