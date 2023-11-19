extends Node3D
var global_target : Vector3

var body_controler: PIDControler = PIDControler.new(1500, 0, 250)
var cannon_controler: PIDControler = PIDControler.new(1500, 100, 300)

var fire_cooldown_sec: float = .2
var burst_count: float = 5
var burst_cooldown_sec: float = 2

var burst_current_countdown: int = burst_count
var fire_current_cooldown: float = 0 


func process_fire(delta):
	fire_current_cooldown -= delta

	if fire_current_cooldown <= 0:
		var bullet = preload("res://assets/bullet.tscn").instantiate()
		bullet.transform = %shoot_center.global_transform
		bullet._process(-fire_current_cooldown)
		get_tree().root.add_child(bullet)
		
		burst_current_countdown -= 1
		if burst_current_countdown <= 0:
			fire_current_cooldown += burst_cooldown_sec
			burst_current_countdown += burst_count
		else:
			fire_current_cooldown += fire_cooldown_sec


class PIDControler:
	var previous_error: float = INF
	var error_integral: float = 0
	var pid: Vector3

	func _init(p:float, i:float, d:float):
		self.pid = Vector3(p,i,d)

	func process(error: float, delta: float) -> float:
		if previous_error == INF:
			previous_error = error
		error_integral += error * delta
		var error_derivate = (error - previous_error ) / delta
		previous_error = error
		return pid.dot(Vector3(error, error_integral, error_derivate))


func process_automation(delta):
	# Compute the aim vector in the body basis.
	var body_local = %aim_center.to_local(global_target)
	
	# Pilot body roation around y axis to maintain the target in xy plane.
	var body_error = -atan2(body_local.z, body_local.x)
	var body_control = body_controler.process(body_error, delta)
	%body.apply_torque_impulse(Vector3(0, body_control * delta, 0))
	
	var target_angle = atan2(body_local.y, sqrt(body_local.x *body_local.x + body_local.z*body_local.z))
	var cannon_error = (target_angle - %cannon.rotation.z)
	var cannon_control = cannon_controler.process(cannon_error, delta)
#	%cannon.apply_torque_impulse(
#		%cannon.global_transform.basis * Vector3(0, 0, cannon_control * delta))


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	process_fire(delta)
	process_automation(delta)
