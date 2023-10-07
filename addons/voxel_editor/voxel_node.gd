@tool
extends Node3D

@export var map :Dictionary = {}

static func coord_to_name(coord: Vector3i):
	return "%s" % coord

func set_cell(coord: Vector3i, value: int):
	print("set cell ", coord, " ", value)
	if value == 0:
		map.erase(coord)
		var child = get_node(NodePath(coord_to_name(coord)))
		if child:
			print("remove child ", child)
			remove_child(child)
			child.queue_free()
	else:
		if value in map:
			return
		map[coord] = value
		_instantiate(coord)
	
func _instantiate(coord: Vector3i):
	var child = preload("library.tscn").instantiate()
	child.name = coord_to_name(coord)
	child.position = Vector3(coord)
#	child.set_meta("_edit_lock_", true)
	add_child(child)
	print("instantiate ", {child=child, coord=coord})
	# No need to set owner as we don't want this child to be persisted
	# box.set_owner(get_tree().get_edited_scene_root())

func _ready():
	print("Ready")
	if map.size() == 0:
		map[Vector3i(0,0,0)] = 1
	for key in map.keys():
		_instantiate(key)

func _enter_tree():
	print("Add box to Voxel")
	# Clicking a children will edit this node.
	set_meta("_edit_group_", true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
