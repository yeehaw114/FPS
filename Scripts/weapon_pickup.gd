extends RigidBody3D
class_name EquipableWeapon

@export var weapon_resource: WeaponResource

func interact():
	#If weapon Equip
	#If button press
	#if door open, etc...
	pass

#free object from memory after the player equips it
func despawn():
	queue_free()
