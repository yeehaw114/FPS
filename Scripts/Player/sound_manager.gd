extends Node3D

@onready var footstep_sfx: AudioStreamPlayer3D = $FootstepSFX

const footstep_sfx_1 := preload("res://Sounds/Footsteps/concrete_footstep_1.wav")

func play_footstep():
	footstep_sfx.stream = footstep_sfx_1
	footstep_sfx.pitch_scale = randf_range(0.9, 1.1)	#randomize pitch
	footstep_sfx.stop()
	footstep_sfx.play()

func queue_stream(stream: AudioStream):
	pass
	
