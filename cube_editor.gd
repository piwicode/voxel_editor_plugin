extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		var origin = $Camera.project_ray_origin(event.position)
		var end = origin + $Camera.project_ray_normal(event.position) * 200
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.collide_with_areas = true
		query.collide_with_bodies = true

		var result = space_state.intersect_ray(query)
		if not result:
			return
		# TODO: Here I also have to transform the normal.
		var local_position =  $GridMap.to_local(result.position)
		var local_normal = result.normal
		var map_position = $GridMap.local_to_map(local_position - local_normal)
		map_position += Vector3i(local_normal.round())
		$GridMap.set_cell_item(map_position, 0, 0)
		print("set_cell_item ", map_position)
		print(event)
		print(local_position,local_normal)		
		print(result)
	else:
		pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
