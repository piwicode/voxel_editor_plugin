@static_unload @tool
class_name Math

const BOX_AXIS_VALUES = [-0.5, 0.5]

# All the possible transformation of a cube in a cube.
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

const FACE_SHIFT: Dictionary = {
	Vector3i(1, 0, 0): 1,
	Vector3i(0, 1, 0): 2,
	Vector3i(0, 0, 1): 4,
	Vector3i(-1, 0, 0): -1,
	Vector3i(0, -1, 0): -2,
	Vector3i(0, 0, -1): -4
}

# Maps {-1, 0, 1}³ vector to the pointed face, edge or vertex bit mask.
static var ID_MASK: Dictionary = __gen_id_masks()


# Borrowed from https://math.stackexchange.com/questions/1993953/closest-points-between-two-lines
static func line_intersection(
	line_position: Vector3, line_normal: Vector3, ray_position: Vector3, ray_normal: Vector3
) -> Vector3:
	var pos_diff = line_position - ray_position
	var cross_normal = line_normal.cross(ray_normal).normalized()
	var rejection = pos_diff - pos_diff.project(ray_normal) - pos_diff.project(cross_normal)
	var distance_to_line_pos = rejection.length() / line_normal.dot(rejection.normalized())
	var closest_approach = line_position - line_normal * distance_to_line_pos
	return closest_approach


# Decomposes a vector into an array of non zero axis aligned components.
static func enumerate_units(v: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if v.x:
		result.append(Vector3i(v.x, 0, 0))
	if v.y:
		result.append(Vector3i(0, v.y, 0))
	if v.z:
		result.append(Vector3i(0, 0, v.z))
	return result


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


static func __gen_id_masks() -> Dictionary:
	const DIRECTION_MASK_PAIRS = [
		[Vector3(-1, -1, -1), 0x01], [Vector3(0, -1, -1), 0x03], [Vector3(0, 0, -1), 0x0F]  # Vertex x=0, y=0, and z=0.  # Edge where z=0 and y=0.  # Face where z=0.
	]
	var masks = {}
	for direction_mask in DIRECTION_MASK_PAIRS:
		var direction = direction_mask[0]
		var mask = direction_mask[1]
		for basis in ORTHO_BASES:
			masks[Vector3i(basis * direction)] = transform_id(mask, basis)
	print("__gen_id_maskss")
	return masks


static func shift_face(mesh_id: int, direction: Vector3i):
	var amount = FACE_SHIFT[direction]
	return mesh_id << amount if amount > 0 else mesh_id >> -amount


static func z_symmetry(mesh_id: int):
	return (mesh_id >> 4) | ((mesh_id & 0xf) << 4)
