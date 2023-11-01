class_name Graphs


class CellGraph:
	# Appends neighbours to the neighbouts list without clearing.it.
	func adjacent(vertex: Vector3i, neighbours: PackedVector3Array):
		assert(false)


static func DFS(g: CellGraph, start: Vector3i) -> Array:
	var visited = {}
	var backlog: PackedVector3Array = PackedVector3Array()
	backlog.append(start)
	while not backlog.is_empty():
		var v = Vector3i(backlog[-1])
		# TODO: use -1 as an inde when supported bu Godot.
		backlog.remove_at(backlog.size() - 1)
		if not v in visited:
			visited[v] = true
			g.adjacent(v, backlog)
	return visited.keys()
