extends RigidBody3D
class_name EquipableWeapon

@export var weapon_resource: WeaponResource

func _ready() -> void:
	if weapon_resource:
		var model = weapon_resource.glb_model.instantiate()
		self.add_child(model)
		model.scale = weapon_resource.weapon_pickup_scale

func interact():
	#If weapon Equip
	#If button press
	#if door open, etc...
	pass

#free object from memory after the player equips it
func despawn():
	queue_free()
