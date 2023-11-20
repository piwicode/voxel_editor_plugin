extends Node3D
var global_target : Vector3

var body_controler: PIDControler = PIDControler.new(1500, 0, 250)
var cannon_controler: PIDControler = PIDControler.new(1500, 0, 500)

const fire_cooldown_sec: float = .2
const burst_count: float = 5
const burst_cooldown_sec: float = 2

var burst_current_countdown: int = burst_count
var fire_current_cooldown: float = 0 

var cannon_lower: float
var cannon_upper: float

# Called when the node enters the scene tree for the first time.
func _ready():
	cannon_lower = -%cannon_joint["angular_limit/upper"] 
	cannon_upper = -%cannon_joint["angular_limit/lower"]
	
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
	var log: bool = false
	var log_countdown : int = 0
	func _init(p:float, i:float, d:float):
		self.pid = Vector3(p,i,d)

	func process(error: float, delta: float) -> float:
		if previous_error == INF:
			previous_error = error
		error_integral += error * delta
		var error_derivate = (error - previous_error) / delta
		previous_error = error
		if log:
			log_countdown -= 1
			if log_countdown <= 0:
				log_countdown = 8
				print("error: %f -> %f   int: %f -> %f   der: %f -> %f  c: %f" % [
				error, error * pid.x, 
				error_integral, error_integral * pid.y,
				error_derivate, error_derivate * pid.z,
				pid.dot(Vector3(error, error_integral, error_derivate))])
		return pid.dot(Vector3(error, error_integral, error_derivate))


func process_automation(delta):
	# Compute the aim vector in the body basis.
	var body_local = %aim_center.to_local(global_target)
	
	# Pilot body roation around y axis to maintain the target in xy plane.
	var body_error = -atan2(body_local.z, body_local.x)
	var body_control = body_controler.process(body_error, delta)
	%body.apply_torque_impulse(Vector3(0, body_control * delta, 0))
	
	# Pilot the cannon rotation.
	var target_angle = atan2(body_local.y, sqrt(body_local.x *body_local.x + body_local.z*body_local.z))
	# Do not target something out of range, otherwise the integral grows out of
	# control.
	target_angle = clamp(target_angle, cannon_lower, cannon_upper)
	var cannon_error = (target_angle - %cannon.rotation.z)

#	cannon_controler.pid = Vector3(1500, 0, 500)
#	cannon_controler.log = true
	var i = cannon_controler.error_integral
	var cannon_control = cannon_controler.process(cannon_error, delta)
	
	%cannon.apply_torque_impulse(
		%cannon.global_transform.basis * Vector3(0, 0, cannon_control * delta))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	process_fire(delta)
	process_automation(delta)
