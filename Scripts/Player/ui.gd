extends Control

@onready var speed_label: Label = $SpeedLabel

func update_speed_label(speed:float) -> void:
	var capped_speed = snapped(speed,0.01)
	speed_label.text = str(capped_speed)+' u/s'
