@tool
class_name Math


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


## Transforms intra-cell coordinates ([-.5, .5]³) into a snapped vector
## ({-1, 0, 1}³) pointing at the clicked primitive.
## The number of non null component depend on the typf of primitive:
## 0 is an inner face, 1 is a cube face, 2 is a cube edge, 3 is a cube corner.
static func snap_one_sub_element(cell_local_pick: Vector3) -> Vector3i:
	const snap_size = .15
	# Assuming a pick on a cell from with coordinates from [-.5,.5]
	return Vector3i(cell_local_pick * 2 * (1.0 + snap_size))


## Decomposes a vector into an array of non zero axis aligned components.
static func enumerate_units(v: Vector3i) -> Array:
	var result = []
	if v.x:
		result.append(Vector3i(v.x, 0, 0))
	if v.y:
		result.append(Vector3i(0, v.y, 0))
	if v.z:
		result.append(Vector3i(0, 0, v.z))
	return result


static func mesh_id_bit(v: Vector3i):
	assert(v.abs() == Vector3i.ONE)
	return 1 << ((v.x + 1) / 2 + (v.y + 1) / 2 * 2 + (v.z + 1) / 2 * 4)
