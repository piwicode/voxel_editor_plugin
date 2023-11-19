extends Node3D


var speed: Vector3
var ttl : float = 4

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _enter_tree():
	speed = 300 * global_transform.basis.y

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position += speed * delta
	position.max_axis_index()
	ttl -= delta
	if ttl < 0:
		queue_free()
