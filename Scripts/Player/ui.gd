extends Control

@onready var speed_label: Label = $SpeedLabel
@onready var ammo_label: Label = $AmmoLabel

func _ready() -> void:
	ammo_label.hide()

func update_speed_label(speed:float) -> void:
	var capped_speed = snapped(speed,0.01)
	speed_label.text = str(capped_speed)+' u/s'

func update_ammo_label(ammo:int, total_ammo := 20) -> void:
	ammo_label.text = str(ammo)+"/"+str(total_ammo)

func has_weapon_equiped(toggle: bool):
	if toggle:
		ammo_label.show()
	else:
		ammo_label.hide()
