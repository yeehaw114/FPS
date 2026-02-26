extends Node3D

func emit_flash():
	%MuzzlePlanes.emitting = true
	%MuzzleCones.emitting = true
	%BeamFlash.emitting = true
	%Sparks.emitting = true
