extends Node3D

var velocity: Vector3 = Vector3.ZERO
var target_node: Node3D

@export var muzzle_flash : Node3D
@export var target_object : Node3D
@export var recoil_rotation_x : Curve
@export var recoil_rotation_z : Curve
@export var recoil_position_z : Curve
@export var recoil_amplitude := Vector3(1,1,1)
@export var lerp_speed : float = 1
@export var recoil_speed : float = 1

var def_pos : Vector3
var def_rot : Vector3
var target_rot : Vector3
var target_pos : Vector3
var current_time : float
var returning := false
var weapon_resource: WeaponResource

func _ready():
	#set_values()
	pass

func lerp_weapon(delta):
	if current_time < 1:
		current_time += delta * recoil_speed
		target_object.position.z = lerp(target_object.position.z, def_pos.z + target_pos.z, lerp_speed * delta)
		target_object.rotation.z = lerp(target_object.rotation.z, def_rot.z + target_rot.z, lerp_speed * delta)
		target_object.rotation.x = lerp(target_object.rotation.x, def_rot.x + target_rot.x, lerp_speed * delta)
		
		target_rot.z = recoil_rotation_z.sample(current_time) * recoil_amplitude.y
		target_rot.x = recoil_rotation_x.sample(current_time) * -recoil_amplitude.x
		target_pos.z = recoil_position_z.sample(current_time) * recoil_amplitude.z
		
	target_object.position.z = lerp(target_object.position.z, def_pos.z, lerp_speed * delta)
	target_object.rotation.z = lerp(target_object.rotation.z, def_rot.z, lerp_speed * delta)
	target_object.rotation.x = lerp(target_object.rotation.x, def_rot.x, lerp_speed * delta)

func apply_recoil():
	recoil_amplitude.y *= -1 if randf() > 0.5 else 1
	target_rot.z = recoil_rotation_z.sample(0) * recoil_amplitude.y
	target_rot.x = recoil_rotation_x.sample(0) * -recoil_amplitude.x
	target_pos.z = recoil_position_z.sample(0) * recoil_amplitude.z
	current_time = 0

func set_values():
	if target_object and weapon_resource:
		def_pos = weapon_resource.view_model_pos
		var rot_deg: Vector3 = weapon_resource.view_model_rot
		def_rot = Vector3(
			deg_to_rad(rot_deg.x),
			deg_to_rad(rot_deg.y),
			deg_to_rad(rot_deg.z)
		)
		current_time = 1
