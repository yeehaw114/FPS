extends Node3D
class_name Gun

@export var muzzle_flash : Node3D

var weapon_resource : WeaponResource

func _ready():
	#set_values()
	pass

func _physics_process(delta):
	%RecoilManager.lerp_weapon(delta)

func set_target_object(weapon: WeaponResource):
	weapon_resource = weapon_resource
	%RecoilManager.target_object = self
	%RecoilManager.weapon_resource = weapon
	%RecoilManager.set_values()

func apply_recoil():
	%RecoilManager.apply_recoil()

func emit_muzzle_flash():
	if muzzle_flash:
		muzzle_flash.emit_flash()
