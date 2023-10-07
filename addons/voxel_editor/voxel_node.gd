@tool
extends Node3D

@export var map :Dictionary = {}

func __to_name(coord: Vector3i):
	return "%s" % coord

func set_cell(coord: Vector3i, value: int):
	print("set cell ", coord, " ", value)
	if value == 0:
		map.erase(coord)
		for c in get_children():
			print(c.name)
		var child = get_node(NodePath(__to_name(coord)))
		if child:
			print("remove child ", child)
			remove_child(child)
			child.queue_free()
	else:
		if value in map:
			return
		map[coord] = value
		instantiate(coord)
	
func instantiate(coord: Vector3i):
	var child = preload("library.tscn").instantiate()
	child.name = __to_name(coord)
	child.position = Vector3(coord)
	add_child(child)
	print("instantiate ", {child=child, coord=coord})
	# No need to set owner as we don't want this child to be persisted
	# box.set_owner(get_tree().get_edited_scene_root())

func _ready():
	print("Ready")
	if map.size() == 0:
		map[Vector3i(0,0,0)] = 1
	for key in map.keys():
		instantiate(key)

func _enter_tree():
	print("Add box to Voxel")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
