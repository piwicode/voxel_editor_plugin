extends Node3D

var speed = 10
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += basis.x * speed * delta
	
	#rotation.x += input.x * .6 * delta
	rotation.y -= input.x * .6 * delta
	rotation.z += input.y * .6 * delta
