extends Node3D

var rng = RandomNumberGenerator.new()


# Called when the node enters the scene tree for the first time.
func _ready():
	%turret_asm.global_target = Vector3(30, 30, 0)
	%target.position = %turret_asm.global_target

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		%target.position = Vector3(
				rng.randi_range(20, 40), 
				rng.randi_range(-20, 20),
				rng.randi_range(-20, 20)
				)
		for child in get_children():
			if child is Turret:
				child.global_target = %target.position

# 1.0473541021347
#-0.12435601651669
