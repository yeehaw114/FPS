extends Node3D

@export var interact_raycast : RayCast3D
@export var interact_ui_label : Label

var current_interactable_object : Node3D = null
var mouse_over_interactable := false
var can_interact := true

func check_if_raycast_hit_interactable(delta) -> bool:
	if interact_raycast and is_instance_valid(interact_raycast):
		if interact_raycast.is_colliding():
			mouse_over_interactable = true
			current_interactable_object = interact_raycast.get_collider()
			set_interact_label('[E] Interact')
			return true
		set_interact_label('')
		mouse_over_interactable = false
		current_interactable_object = null
		return false
	return false
	
#If the label isnt started with null it doesnt set the label properly at first
var set_string_last_frame : String = ''
func set_interact_label(text: String) -> void:
	if interact_ui_label and is_instance_valid(interact_ui_label):
		if text == set_string_last_frame:
			return

		set_string_last_frame = text
		interact_ui_label.text = text
		
func attempt_interaction() -> Node3D:
	if can_interact and mouse_over_interactable and current_interactable_object != null:
		print('You can interact with: '+str(current_interactable_object))
		return current_interactable_object
	return null
